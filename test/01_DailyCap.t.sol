// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {DailyCappedStock} from "../src/01-daily-cap/DailyCappedStock.sol";
import {DailyCappedStockFixed} from "../src/01-daily-cap/DailyCappedStockFixed.sol";
import {VenueRouter, IStock} from "../src/01-daily-cap/VenueRouter.sol";

contract DailyCapTest is Test {
    address holder = makeAddr("holder");
    address buyer = makeAddr("buyer");

    uint256 constant SUPPLY = 1_000_000;

    /// 한도 검사 자체는 멀쩡하다는 것부터 확인한다.
    /// 오더북 경로(transfer)에서는 2,500주에서 정확히 막힌다.
    function test_Cap_WorksOnOrderbookPath() public {
        DailyCappedStock stock = new DailyCappedStock(holder, SUPPLY);
        assertEq(stock.dailyCap(), 2500, "0.25% of 1,000,000 ADV");

        vm.prank(holder);
        stock.transfer(buyer, 2500); // 오늘 한도를 정확히 소진

        vm.prank(holder);
        vm.expectRevert("DAILY_CAP");
        stock.transfer(buyer, 1); // 1주만 더 보내도 막힌다
    }

    /// 같은 토큰을 AMM 라우터 경로(transferFrom)로 거래하면 한도가 전혀 세지 않는다.
    /// 기사에서 TSV 는 오더북과 AMM 을 모두 쓸 수 있다고 했으므로 비정상 경로가 아니다.
    function test_Exploit_RouterPathBypassesCap() public {
        DailyCappedStock stock = new DailyCappedStock(holder, SUPPLY);
        VenueRouter router = new VenueRouter(IStock(address(stock)));

        vm.prank(holder);
        stock.approve(address(router), SUPPLY);

        // 하루 한도 2,500주의 40배를 같은 날 한 번에 체결한다
        router.swap(holder, buyer, 100_000);

        assertEq(stock.balanceOf(buyer), 100_000, "40x the daily cap settled");
        assertEq(stock.countedVolume(), 0, "meter counted nothing");
    }

    /// 수정본은 잔액이 움직이는 _move 한 곳에서 집계하므로 라우터 경로도 같은 한도를 받는다.
    function test_Fix_RouterPathAlsoCounted() public {
        DailyCappedStockFixed stock = new DailyCappedStockFixed(holder, SUPPLY);
        VenueRouter router = new VenueRouter(IStock(address(stock)));

        vm.prank(holder);
        stock.approve(address(router), SUPPLY);

        vm.expectRevert("DAILY_CAP");
        router.swap(holder, buyer, 100_000); // 같은 거래가 이제 막힌다

        router.swap(holder, buyer, 2500); // 한도 안이면 정상 체결
        assertEq(stock.countedVolume(), 2500, "router path went through the meter");

        vm.expectRevert("DAILY_CAP");
        router.swap(holder, buyer, 1);

        // 날짜가 바뀌면 집계가 초기화된다
        vm.warp(block.timestamp + 1 days);
        router.swap(holder, buyer, 2500);
        assertEq(stock.countedVolume(), 2500, "cap resets on the next day");
    }

    /// 내 수정본도 완전하지 않다. 집계를 일 단위(block.timestamp / 1 days)로 끊었기 때문에
    /// 자정 직전과 직후에 나눠 체결하면 2초 안에 하루 한도의 2배가 처리된다.
    /// 기사의 "평균 일일 거래량의 0.25%" 를 지키려면 롤링 윈도우가 필요해 보인다.
    function test_Limit_DayBoundaryAllowsDoubleCap() public {
        DailyCappedStockFixed stock = new DailyCappedStockFixed(holder, SUPPLY);

        // 오늘이 끝나기 1초 전으로 이동
        uint256 justBeforeMidnight = ((block.timestamp / 1 days) + 1) * 1 days - 1;
        vm.warp(justBeforeMidnight);

        vm.prank(holder);
        stock.transfer(buyer, 2500); // 오늘치 한도를 다 쓴다

        vm.warp(justBeforeMidnight + 1); // 1초 뒤 -> 날짜가 바뀐다
        vm.prank(holder);
        stock.transfer(buyer, 2500); // 새 한도로 다시 2,500주

        assertEq(stock.balanceOf(buyer), 5000, "2x the daily cap settled within 2 seconds");
    }
}

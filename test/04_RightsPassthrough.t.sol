// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {RightsPassthroughStock} from "../src/04-rights-passthrough/RightsPassthroughStock.sol";
import {RightsPassthroughStockFixed} from "../src/04-rights-passthrough/RightsPassthroughStockFixed.sol";

contract RightsPassthroughTest is Test {
    address issuer = makeAddr("issuer");   // 애플 (배당 지급 주체)
    address alice = makeAddr("alice");     // 600주 보유자
    address bob = makeAddr("bob");         // 400주 보유자
    address mallory = makeAddr("mallory"); // 배당 선언 후에 들어온 매수자

    uint256 constant SUPPLY = 1000;
    uint256 constant POOL = 10 ether;

    /// alice 600 / bob 400 으로 나눠둔 토큰을 만들고 배당을 선언한다.
    function _setUpNaive() internal returns (RightsPassthroughStock tok) {
        tok = new RightsPassthroughStock(issuer, alice, SUPPLY);
        vm.prank(alice);
        tok.transfer(bob, 400);

        vm.deal(issuer, POOL);
        vm.prank(issuer);
        tok.declareDividend{value: POOL}();
    }

    /// 아무도 움직이지 않으면 지분대로 정확히 나뉜다. 배당 기능 자체는 동작한다.
    function test_Dividend_SplitsByShare() public {
        RightsPassthroughStock tok = _setUpNaive();

        vm.prank(alice);
        tok.claim();
        vm.prank(bob);
        tok.claim();

        assertEq(alice.balance, 6 ether, "alice receives 60 percent");
        assertEq(bob.balance, 4 ether, "bob receives 40 percent");
        assertEq(address(tok).balance, 0, "the whole pool is distributed");
    }

    /// 그런데 배당 자격이 기준일이 아니라 청구 시점 잔고에 붙어 있다.
    /// 선언 뒤에 산 사람이 배당을 가져가고, 선언 시점 보유자는 못 받는다.
    /// 총액 10 이더는 그대로 맞는데 받는 사람이 바뀐다.
    function test_Exploit_BuyAfterDeclarationTakesDividend() public {
        RightsPassthroughStock tok = _setUpNaive();

        // 배당 선언 이후에 bob 이 mallory 에게 400주를 넘긴다.
        vm.prank(bob);
        tok.transfer(mallory, 400);

        vm.prank(mallory);
        tok.claim();
        assertEq(mallory.balance, 4 ether, "a buyer after the record date collects the dividend");

        // 선언 시점에 400주를 들고 있던 bob 은 이제 지분이 0 이라 받을 수 없다.
        vm.prank(bob);
        vm.expectRevert("NO_SHARE");
        tok.claim();
        assertEq(bob.balance, 0, "the holder at declaration time gets nothing");
    }

    /// 수정본은 선언 시점 잔고로 나눈다. 선언 이후의 이동은 자격을 옮기지 못하고,
    /// 받은 뒤 토큰을 넘겨도 새 주소가 다시 받을 수 없다.
    function test_Fix_DividendFollowsRecordDate() public {
        RightsPassthroughStockFixed tok = new RightsPassthroughStockFixed(issuer, alice, SUPPLY);
        vm.prank(alice);
        tok.transfer(bob, 400);

        vm.deal(issuer, POOL);
        vm.prank(issuer);
        tok.declareDividend{value: POOL}();

        // 같은 우회 시도. 이번엔 자격이 따라가지 않는다.
        vm.prank(bob);
        tok.transfer(mallory, 400);

        vm.prank(mallory);
        vm.expectRevert("NO_SHARE");
        tok.claim();

        vm.prank(bob);
        tok.claim();
        assertEq(bob.balance, 4 ether, "the holder at declaration time keeps the dividend");

        // 받은 뒤 토큰을 넘기는 이중 수령 경로도 같은 이유로 막힌다.
        vm.prank(alice);
        tok.claim();
        vm.prank(alice);
        tok.transfer(mallory, 600);

        vm.prank(mallory);
        vm.expectRevert("NO_SHARE");
        tok.claim();

        assertEq(alice.balance, 6 ether, "alice is paid once");
        assertEq(address(tok).balance, 0, "the pool is neither overdrawn nor left over");
    }
}

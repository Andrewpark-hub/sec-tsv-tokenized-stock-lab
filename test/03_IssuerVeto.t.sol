// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {TokenizationRegistry} from "../src/03-issuer-veto/TokenizationRegistry.sol";
import {TokenizationRegistryFixed} from "../src/03-issuer-veto/TokenizationRegistryFixed.sol";

contract IssuerVetoTest is Test {
    address platform = makeAddr("platform"); // TSV 운영자
    address issuer = makeAddr("issuer");     // 애플 (발행사)
    address aapl = makeAddr("AAPL");         // 토큰화 대상 종목

    /// 반대하면 이번 상장은 확실히 막힌다. 조항 자체는 동작한다.
    function test_Veto_BlocksImmediateListing() public {
        TokenizationRegistry reg = new TokenizationRegistry(platform);

        vm.prank(platform);
        reg.registerIssuer(aapl, issuer);
        vm.prank(platform);
        reg.notifyIssuer(aapl);

        vm.prank(issuer);
        reg.veto(aapl); // 30일 안에 반대

        vm.warp(block.timestamp + 30 days);
        vm.prank(platform);
        vm.expectRevert("NO_NOTICE");
        reg.list(aapl);

        assertFalse(reg.listed(aapl), "vetoed listing did not go through");
    }

    /// 그런데 거부 사실이 저장되지 않으니 플랫폼이 다시 통지하면 시계가 새로 돈다.
    /// 발행사가 두 번째 통지를 놓치면 결국 상장된다.
    function test_Exploit_RenotifyResetsVeto() public {
        TokenizationRegistry reg = new TokenizationRegistry(platform);

        vm.prank(platform);
        reg.registerIssuer(aapl, issuer);
        vm.prank(platform);
        reg.notifyIssuer(aapl);

        vm.prank(issuer);
        reg.veto(aapl); // 발행사가 분명히 반대했다

        // 다음 날 플랫폼이 그냥 다시 통지한다. 막는 조건이 없다.
        vm.warp(block.timestamp + 1 days);
        vm.prank(platform);
        reg.notifyIssuer(aapl);

        // 이번엔 발행사가 놓쳤다. 30일이 지나면 상장된다.
        vm.warp(block.timestamp + 30 days);
        vm.prank(platform);
        reg.list(aapl);

        assertTrue(reg.listed(aapl), "listed despite the issuer having objected");
    }

    /// 수정본은 거부를 상태로 남겨 재통지 자체를 막고, 푸는 것은 발행사만 할 수 있다.
    function test_Fix_VetoIsPermanent() public {
        TokenizationRegistryFixed reg = new TokenizationRegistryFixed(platform);

        vm.prank(platform);
        reg.registerIssuer(aapl, issuer);
        vm.prank(platform);
        reg.notifyIssuer(aapl);

        vm.prank(issuer);
        reg.veto(aapl);

        // 같은 우회 시도가 통지 단계에서 막힌다
        vm.warp(block.timestamp + 1 days);
        vm.prank(platform);
        vm.expectRevert("VETOED");
        reg.notifyIssuer(aapl);

        // 발행사가 마음을 바꿔 직접 풀어주면 다시 진행할 수 있다
        vm.prank(issuer);
        reg.allowTokenization(aapl);

        vm.prank(platform);
        reg.notifyIssuer(aapl);
        vm.warp(block.timestamp + 30 days);
        vm.prank(platform);
        reg.list(aapl);

        assertTrue(reg.listed(aapl), "listing proceeds only after the issuer lifts the veto");
    }
}

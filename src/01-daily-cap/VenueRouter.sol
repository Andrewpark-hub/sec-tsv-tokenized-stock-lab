// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/// @notice 토큰이 외부로 노출하는 함수 중 라우터가 쓰는 것만 추린 인터페이스.
interface IStock {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @notice AMM 유동성 풀 라우터를 흉내낸 컨트랙트.
///         공격자가 아니라 기사에서 허용한 **정상 거래 경로**라는 점이 핵심이다.
///         보유자에게 approve 를 받아 transferFrom 으로 체결한다.
contract VenueRouter {
    IStock public immutable stock;

    constructor(IStock _stock) {
        stock = _stock;
    }

    /// @dev 풀을 거쳐 체결된 것처럼 보유자 -> 매수자로 토큰을 옮긴다.
    function swap(address from, address to, uint256 amount) external {
        stock.transferFrom(from, to, amount);
    }
}

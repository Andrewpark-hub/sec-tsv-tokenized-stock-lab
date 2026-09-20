// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/// @title 04. 권리 승계 — 기준일 없이 "지금 잔고" 로 나누는 배당
/// @notice 기사: "토큰화가 가능한 주식은 실제 주식과 동일한 권리를 보장하는
///         토큰으로 제한된다. 단순히 주식 가격만 추종하는 것이 아니라
///         배당권·의결권 등 기존 주식과 동일한 권리를 보장해야 한다."
///         가격만 추종하는 로빈후드 Stock Tokens, 크라켄 xStocks 는 면제를 쓰려면
///         재설계가 필요할 수 있다고 한 그 조항이다.
///
/// @dev 권리를 "붙이는" 것 자체는 어렵지 않다. 발행사가 배당금을 넣고 보유자가
///      지분만큼 가져가면 된다. 이 버전도 그렇게 되어 있고, 중복 수령을 막으려고
///      claimed 매핑까지 두었다. 총액도 정확히 맞는다.
///
///      빠진 것은 기준일(record date)이다. 실제 주식은 "기준일에 주주명부에
///      있던 사람" 에게 배당이 간다. 이 컨트랙트는 "청구하는 순간의 잔고" 로
///      나눈다. 배당 선언과 청구 사이에 토큰이 움직이면 권리가 같이 따라간다.
///      claimed 도 주소를 기준으로만 막으므로, 토큰이 새 주소로 넘어가면
///      그 주소는 아직 받은 적이 없는 주소다.
contract RightsPassthroughStock {
    string public constant name = "Tokenized AAPL";
    string public constant symbol = "tAAPL";

    address public immutable issuer;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    uint256 public round;                      // 배당 회차 (0 이면 아직 배당 없음)
    mapping(uint256 => uint256) public poolOf; // 회차 -> 배당 총액
    mapping(uint256 => mapping(address => bool)) public claimed;

    constructor(address _issuer, address holder, uint256 supply) {
        issuer = _issuer;
        totalSupply = supply;
        balanceOf[holder] = supply;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "BALANCE");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    /// @notice 발행사가 배당금을 넣고 회차를 연다.
    function declareDividend() external payable {
        require(msg.sender == issuer, "NOT_ISSUER");
        require(msg.value > 0, "NO_VALUE");
        round += 1;
        poolOf[round] = msg.value;
    }

    /// @notice 지분만큼 배당을 가져간다.
    /// @dev 지분을 "지금" 잔고로 계산한다. 기준일 잔고가 아니다. ← 취약점
    function claim() external {
        uint256 r = round;
        require(r != 0, "NO_DIVIDEND");
        require(!claimed[r][msg.sender], "ALREADY_CLAIMED");
        claimed[r][msg.sender] = true;

        uint256 amount = poolOf[r] * balanceOf[msg.sender] / totalSupply;
        require(amount > 0, "NO_SHARE");
        require(address(this).balance >= amount, "POOL_EMPTY");
        payable(msg.sender).transfer(amount);
    }
}

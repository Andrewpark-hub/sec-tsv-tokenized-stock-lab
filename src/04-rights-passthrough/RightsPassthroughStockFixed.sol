// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/// @title 04-fixed. 배당은 기준일 잔고로 나눈다
/// @notice 배당 선언 시점의 잔고를 기준일 명부로 보고, 그 이후의 이동은
///         배당 자격에 영향을 주지 않게 한다.
///
/// @dev 고친 부분은 두 군데다.
///      1) 회차별 기준일 잔고(snapshotOf)를 두고
///      2) 토큰이 움직이기 직전에 양쪽의 "움직이기 전 잔고" 를 기록한다(_record)
///      한 번도 움직이지 않은 주소는 기록이 없으므로 현재 잔고가 곧 기준일
///      잔고다. 그래서 모든 보유자를 미리 순회하지 않아도 된다.
///
///      배운 것: 권리 승계는 "배당 함수를 넣었는가" 가 아니라 "어느 시점의
///      명부로 나누는가" 의 문제였다. 총액은 두 버전 모두 정확히 맞는다.
///      다른 것은 그 돈을 누가 받느냐다. 의결권도 같은 모양이다 — 투표한 뒤
///      토큰을 넘기면 받은 주소가 다시 투표할 수 있어 이중 집계가 된다.
contract RightsPassthroughStockFixed {
    string public constant name = "Tokenized AAPL";
    string public constant symbol = "tAAPL";

    address public immutable issuer;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    uint256 public round;
    mapping(uint256 => uint256) public poolOf;
    mapping(uint256 => mapping(address => bool)) public claimed;

    mapping(uint256 => mapping(address => uint256)) public snapshotOf; // 회차 -> 주소 -> 기준일 잔고
    mapping(uint256 => mapping(address => bool)) public recorded;      // 기록해둔 적이 있는가

    constructor(address _issuer, address holder, uint256 supply) {
        issuer = _issuer;
        totalSupply = supply;
        balanceOf[holder] = supply;
    }

    /// @dev 이번 회차에 대해 아직 기록이 없으면, 움직이기 전 잔고를 남긴다.
    function _record(address who) internal {
        uint256 r = round;
        if (r == 0 || recorded[r][who]) return;
        snapshotOf[r][who] = balanceOf[who];
        recorded[r][who] = true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "BALANCE");
        _record(msg.sender);
        _record(to);
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function declareDividend() external payable {
        require(msg.sender == issuer, "NOT_ISSUER");
        require(msg.value > 0, "NO_VALUE");
        round += 1;
        poolOf[round] = msg.value;
    }

    /// @notice 기준일 잔고. 선언 이후 한 번도 움직이지 않았으면 현재 잔고와 같다.
    function balanceAtRecord(uint256 r, address who) public view returns (uint256) {
        return recorded[r][who] ? snapshotOf[r][who] : balanceOf[who];
    }

    function claim() external {
        uint256 r = round;
        require(r != 0, "NO_DIVIDEND");
        require(!claimed[r][msg.sender], "ALREADY_CLAIMED");
        claimed[r][msg.sender] = true;

        uint256 amount = poolOf[r] * balanceAtRecord(r, msg.sender) / totalSupply;
        require(amount > 0, "NO_SHARE");
        require(address(this).balance >= amount, "POOL_EMPTY");
        payable(msg.sender).transfer(amount);
    }
}

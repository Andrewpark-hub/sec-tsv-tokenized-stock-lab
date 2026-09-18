// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/// @title 01-fixed. 계량기를 진입점이 아니라 공통 경로에 단다.
/// @notice 고친 것은 한 줄이다 — _countVolume 호출을 transfer 에서 _move 안으로 옮겼다.
///         잔액이 실제로 움직이는 곳은 _move 하나뿐이므로, 오더북이든 AMM 라우터든
///         앞으로 어떤 함수가 추가되든 모두 같은 계량기를 지나게 된다.
///
/// @dev 22회차에서 배운 cross-function 재진입과 같은 모양이다. 거기서는
///      "가드를 플래그된 함수 하나에만 걸면 형제 함수로 뚫린다" 였고,
///      여기서는 "한도를 진입점 하나에만 걸면 다른 진입점으로 새어나간다" 이다.
///      규제 문장은 "일일 거래량의 0.25%" 한 줄이지만, 컨트랙트에서는
///      "거래량을 어디서 세느냐" 가 사실상 전부다.
contract DailyCappedStockFixed {
    string public constant name = "Tokenized AAPL";
    string public constant symbol = "tAAPL";

    uint256 public constant AVG_DAILY_VOLUME = 1_000_000;
    uint256 public constant CAP_BPS = 25;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 public countedDay;
    uint256 public countedVolume;

    constructor(address holder, uint256 supply) {
        totalSupply = supply;
        balanceOf[holder] = supply;
        countedDay = block.timestamp / 1 days;
    }

    function dailyCap() public pure returns (uint256) {
        return AVG_DAILY_VOLUME * CAP_BPS / 10000;
    }

    function _countVolume(uint256 amount) internal {
        uint256 day = block.timestamp / 1 days;
        if (day != countedDay) {
            countedDay = day;
            countedVolume = 0;
        }
        require(countedVolume + amount <= dailyCap(), "DAILY_CAP");
        countedVolume += amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _move(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(allowance[from][msg.sender] >= amount, "ALLOWANCE");
        allowance[from][msg.sender] -= amount;
        _move(from, to, amount);
        return true;
    }

    /// @dev 잔액이 움직이는 단 한 곳. 모든 경로가 여기를 지난다.
    function _move(address from, address to, uint256 amount) internal {
        _countVolume(amount);
        require(balanceOf[from] >= amount, "BALANCE");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
    }
}

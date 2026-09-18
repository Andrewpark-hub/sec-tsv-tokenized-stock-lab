// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/// @title 01. 일일 거래량 한도(ADV Cap) — 한쪽 경로에만 걸린 집계
/// @notice SEC 혁신 면제 조건 중 "유동성 1등급 종목은 평균 일일 거래량(ADV)의
///         0.25%까지만 처리할 수 있다" 를 온체인에서 강제해보려는 최소 예제다.
///         (출처: ZDNet 2026-09-18 기사. SEC 원문 규정을 구현한 것이 아니라
///          기사로 보도된 조건 한 줄을 컨트랙트 제약으로 옮겨본 것이다.)
///
/// @dev 기사에는 TSV 가 "오더북" 과 "AMM 유동성 풀" 을 모두 쓸 수 있다고 나온다.
///      그런데 토큰 입장에서 이 둘은 서로 다른 함수로 들어온다.
///        - 오더북 체결 : 보유자가 직접 transfer 를 부른다
///        - AMM 라우터  : 라우터가 approve 를 받아 transferFrom 을 부른다
///      이 버전은 한도 집계를 transfer 에만 걸었다. 그래서 라우터 경로로 오는
///      거래는 한도에 잡히지 않는다. 한도 검사 자체는 "있고", 심지어 잘 동작한다.
///      다만 거래가 들어오는 문이 두 개인데 한 문에만 계량기를 달아둔 것이다.
contract DailyCappedStock {
    string public constant name = "Tokenized AAPL";
    string public constant symbol = "tAAPL";

    // 유동성 1등급 종목이라고 가정한 값 (기사: 1등급은 ADV 의 0.25%)
    uint256 public constant AVG_DAILY_VOLUME = 1_000_000; // 평균 일일 거래량 100만 주
    uint256 public constant CAP_BPS = 25;                 // 0.25% = 25 / 10000

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 public countedDay;    // 집계 중인 날짜
    uint256 public countedVolume; // 그 날짜에 집계된 거래량

    constructor(address holder, uint256 supply) {
        totalSupply = supply;
        balanceOf[holder] = supply;
        countedDay = block.timestamp / 1 days;
    }

    /// @notice 하루에 처리할 수 있는 최대 수량 = 100만 * 0.25% = 2,500 주
    function dailyCap() public pure returns (uint256) {
        return AVG_DAILY_VOLUME * CAP_BPS / 10000;
    }

    /// @dev 날짜가 바뀌면 집계를 0으로 되돌리고, 오늘치 한도를 넘는지 본다.
    function _countVolume(uint256 amount) internal {
        uint256 day = block.timestamp / 1 days;
        if (day != countedDay) {
            countedDay = day;
            countedVolume = 0;
        }
        require(countedVolume + amount <= dailyCap(), "DAILY_CAP");
        countedVolume += amount;
    }

    /// @dev 오더북 경로. 여기에는 계량기가 달려 있다.
    function transfer(address to, uint256 amount) external returns (bool) {
        _countVolume(amount);
        _move(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    /// @dev AMM 라우터 경로. _countVolume 을 넣는 것을 빠뜨렸다. ← 취약점
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(allowance[from][msg.sender] >= amount, "ALLOWANCE");
        allowance[from][msg.sender] -= amount;
        _move(from, to, amount);
        return true;
    }

    function _move(address from, address to, uint256 amount) internal {
        require(balanceOf[from] >= amount, "BALANCE");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
    }
}

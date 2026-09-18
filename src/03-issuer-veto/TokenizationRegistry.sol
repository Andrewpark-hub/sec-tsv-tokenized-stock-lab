// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/// @title 03. 발행사 거부권 — 재통지로 초기화되는 거부
/// @notice 기사: "제3자가 특정 기업 주식을 토큰화하려면 거래 플랫폼은 거래를
///         시작하기 최소 30일 전에 해당 기업에 통지해야 하고, 이 기간 발행사가
///         반대하면 토큰화 주식을 거래할 수 없다."
///         업계에서 핵심 투자자 보호 장치로 평가한다는 그 조항이다.
///
/// @dev 그대로 옮기면 아래처럼 된다. 통지하고, 30일 기다리고, 상장한다.
///      발행사가 반대하면 통지를 지운다.
///      그런데 지우는 것은 "이번 통지" 일 뿐, "반대했다는 사실" 은 남지 않는다.
///      플랫폼이 다음 날 다시 통지하면 30일 시계가 새로 시작되고,
///      이번에 발행사가 놓치면 상장된다.
///      결과적으로 거부권이 아니라 30일짜리 지연권이 된다.
contract TokenizationRegistry {
    uint256 public constant NOTICE_PERIOD = 30 days;

    address public immutable platform; // TSV 운영자

    mapping(address => address) public issuerOf; // 종목 -> 발행사 주소
    mapping(address => uint256) public noticeAt; // 종목 -> 통지 시각 (0 이면 통지 없음)
    mapping(address => bool) public listed;      // 종목 -> 상장 여부

    constructor(address _platform) {
        platform = _platform;
    }

    /// @notice 어느 주소가 그 종목의 발행사인지 등록해둔다. (설정용)
    function registerIssuer(address stock, address issuer) external {
        require(msg.sender == platform, "NOT_PLATFORM");
        require(issuerOf[stock] == address(0), "ALREADY_REGISTERED");
        issuerOf[stock] = issuer;
    }

    /// @notice 플랫폼이 발행사에게 토큰화 계획을 통지한다. 여기서부터 30일.
    function notifyIssuer(address stock) external {
        require(msg.sender == platform, "NOT_PLATFORM");
        require(issuerOf[stock] != address(0), "NO_ISSUER");
        require(!listed[stock], "ALREADY_LISTED");
        noticeAt[stock] = block.timestamp;
    }

    /// @notice 통지 기간 안에 발행사가 반대한다.
    /// @dev 통지만 지운다. 반대했다는 사실이 남지 않는다. ← 취약점
    function veto(address stock) external {
        require(msg.sender == issuerOf[stock], "NOT_ISSUER");
        require(noticeAt[stock] != 0, "NO_NOTICE");
        require(block.timestamp < noticeAt[stock] + NOTICE_PERIOD, "NOTICE_OVER");
        noticeAt[stock] = 0;
    }

    /// @notice 30일이 지나고 반대가 없으면 상장한다.
    function list(address stock) external {
        require(msg.sender == platform, "NOT_PLATFORM");
        require(noticeAt[stock] != 0, "NO_NOTICE");
        require(block.timestamp >= noticeAt[stock] + NOTICE_PERIOD, "NOTICE_PENDING");
        listed[stock] = true;
    }
}

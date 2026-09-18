// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/// @title 03-fixed. 거부를 상태로 남긴다
/// @notice 반대를 "이번 통지의 취소" 가 아니라 "그 종목에 대한 거부" 로 기록한다.
///         한 번 거부하면 재통지 자체가 막히고, 푸는 것은 발행사만 할 수 있다.
///
/// @dev 고친 부분은 세 군데다.
///      1) vetoed 매핑을 두어 거부 사실을 영구 보관
///      2) notifyIssuer 에서 vetoed 를 먼저 확인
///      3) allowTokenization 으로 발행사만 거부를 해제
///
///      배운 것: "30일 안에 반대하면 막힌다" 는 문장은 시간 조건처럼 보이지만,
///      실제로 결정하는 건 "반대가 어디에 저장되는가" 였다.
///      기간을 아무리 정확히 구현해도 거부가 휘발성이면 규제 의도가 사라진다.
contract TokenizationRegistryFixed {
    uint256 public constant NOTICE_PERIOD = 30 days;

    address public immutable platform;

    mapping(address => address) public issuerOf;
    mapping(address => uint256) public noticeAt;
    mapping(address => bool) public listed;
    mapping(address => bool) public vetoed; // 발행사가 반대한 종목

    constructor(address _platform) {
        platform = _platform;
    }

    function registerIssuer(address stock, address issuer) external {
        require(msg.sender == platform, "NOT_PLATFORM");
        require(issuerOf[stock] == address(0), "ALREADY_REGISTERED");
        issuerOf[stock] = issuer;
    }

    function notifyIssuer(address stock) external {
        require(msg.sender == platform, "NOT_PLATFORM");
        require(issuerOf[stock] != address(0), "NO_ISSUER");
        require(!listed[stock], "ALREADY_LISTED");
        require(!vetoed[stock], "VETOED"); // 이미 반대한 종목은 재통지 불가
        noticeAt[stock] = block.timestamp;
    }

    function veto(address stock) external {
        require(msg.sender == issuerOf[stock], "NOT_ISSUER");
        require(noticeAt[stock] != 0, "NO_NOTICE");
        require(block.timestamp < noticeAt[stock] + NOTICE_PERIOD, "NOTICE_OVER");
        vetoed[stock] = true; // 거부 사실을 남긴다
        noticeAt[stock] = 0;
    }

    /// @notice 거부를 푸는 것은 발행사 본인만 할 수 있다.
    function allowTokenization(address stock) external {
        require(msg.sender == issuerOf[stock], "NOT_ISSUER");
        vetoed[stock] = false;
    }

    function list(address stock) external {
        require(msg.sender == platform, "NOT_PLATFORM");
        require(noticeAt[stock] != 0, "NO_NOTICE");
        require(block.timestamp >= noticeAt[stock] + NOTICE_PERIOD, "NOTICE_PENDING");
        require(!vetoed[stock], "VETOED");
        listed[stock] = true;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title RealEstateVerification
 * 여러 기관이 부동산(UID)에 대해 검증 결과를 제출하면,
 * 이를 종합하여 점수/등급을 산정하고, 인증서를 발급하는 예시 컨트랙트.
 */
contract RealEstateVerification {
    // ------------------------------------------------------------------------
    // 1. 구조체 & 상태 변수 정의
    // ------------------------------------------------------------------------

    // 기관(검증자)별 검증 결과를 저장할 구조체
    struct VerificationResult {
        bool exists;     // 검증 결과가 존재하는지 여부
        bool passed;     // 검증 결과 (yes = true, no = false)
        string comment;  // 필요시 코멘트나 기타 부가정보
    }

    // 최종 발급된 인증서 정보
    struct Certificate {
        bool isIssued;        // 인증서 발급 여부
        uint256 score;        // 예시) 100점 만점 환산
        string rating;        // A/B/C 등급
        uint256 issuedAt;     // 발급 시각(블록 타임스탬프)
    }

    // [UID -> (기관 주소 -> VerificationResult)]
    mapping(string => mapping(address => VerificationResult)) private verificationData;

    // [UID -> 인증서]
    mapping(string => Certificate) public certificates;

    // 등록된 기관 목록 및 기관 여부
    mapping(address => bool) public isInstitution;
    address[] public institutionList;

    // 컨트랙트 관리자 (기관 등록/해제 권한)
    address public owner;


    // ------------------------------------------------------------------------
    // 2. 이벤트 정의
    // ------------------------------------------------------------------------
    event InstitutionAdded(address indexed institution);
    event InstitutionRemoved(address indexed institution);
    event VerificationSubmitted(string indexed uid, address indexed institution, bool passed);
    event CertificateIssued(string indexed uid, uint256 score, string rating);


    // ------------------------------------------------------------------------
    // 3. 생성자 (배포 시 한 번 실행)
    // ------------------------------------------------------------------------
    constructor() {
        owner = msg.sender;
    }


    // ------------------------------------------------------------------------
    // 4. 접근 제어자(Modifier)
    // ------------------------------------------------------------------------
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyInstitution() {
        require(isInstitution[msg.sender] == true, "Not registered institution");
        _;
    }


    // ------------------------------------------------------------------------
    // 5. 기관 등록 관련 함수
    // ------------------------------------------------------------------------
    function addInstitution(address _institution) external onlyOwner {
        require(!isInstitution[_institution], "Already an institution");
        isInstitution[_institution] = true;
        institutionList.push(_institution);

        emit InstitutionAdded(_institution);
    }

    function removeInstitution(address _institution) external onlyOwner {
        require(isInstitution[_institution], "Not an institution");
        isInstitution[_institution] = false;

        // institutionList에서 실제로 제거하는 로직(간단 구현 예시)
        for (uint256 i = 0; i < institutionList.length; i++) {
            if (institutionList[i] == _institution) {
                institutionList[i] = institutionList[institutionList.length - 1];
                institutionList.pop();
                break;
            }
        }

        emit InstitutionRemoved(_institution);
    }

    // 기관 목록 조회 (readonly)
    function getInstitutionList() external view returns (address[] memory) {
        return institutionList;
    }


    // ------------------------------------------------------------------------
    // 6. 검증 결과 제출 함수
    // ------------------------------------------------------------------------
    /**
     * @dev 기관이 특정 UID의 검증 결과를 제출하는 함수
     * @param uid 부동산 고유 식별자
     * @param passed yes/no (true/false)
     * @param comment 추가 코멘트(옵션)
     */
    function submitVerification(
        string memory uid,
        bool passed,
        string memory comment
    )
        external
        onlyInstitution
    {
        // 이미 제출한 결과가 있더라도 덮어씁니다(요구사항에 맞게 수정 가능)
        verificationData[uid][msg.sender] = VerificationResult({
            exists: true,
            passed: passed,
            comment: comment
        });

        emit VerificationSubmitted(uid, msg.sender, passed);
    }


    // ------------------------------------------------------------------------
    // 7. 인증서 발급 로직
    // ------------------------------------------------------------------------
    /**
     * @dev UID에 대한 검증 결과를 종합하여 인증서를 발급(점수/등급 산정 후 저장).
     * @param uid 부동산 고유 식별자
     */
    function issueCertificate(string memory uid) external {
        // 이미 발급된 인증서가 있다면, 재발급 여부를 결정 (여기서는 재발급 허용)
        // require(!certificates[uid].isIssued, "Certificate already issued");

        // 검증에 참여한 기관( institutionList )을 순회하여 결과를 집계
        uint256 totalCount = 0;
        uint256 yesCount = 0;

        for (uint256 i = 0; i < institutionList.length; i++) {
            address inst = institutionList[i];
            if (verificationData[uid][inst].exists) {
                totalCount++;
                if (verificationData[uid][inst].passed) {
                    yesCount++;
                }
            }
        }

        // 점수/등급 산정 (예시 로직)
        // - totalCount가 0이면 분모가 되므로 주의
        uint256 score = 0;
        string memory rating = "N/A";

        if (totalCount > 0) {
            score = (yesCount * 100) / totalCount; // 100점 만점 기준
            rating = _calculateRating(score);      // 내부 헬퍼 함수
        }

        // 인증서 정보 저장
        certificates[uid] = Certificate({
            isIssued: true,
            score: score,
            rating: rating,
            issuedAt: block.timestamp
        });

        emit CertificateIssued(uid, score, rating);
    }

    /**
     * @dev 내부 함수. 점수(0~100)에 따른 등급을 간단 분류
     * 예) 80점 이상 = A, 60~79 = B, 40~59 = C, 그 외 D
     */
    function _calculateRating(uint256 score) internal pure returns (string memory) {
        if (score >= 80) {
            return "A";
        } else if (score >= 60) {
            return "B";
        } else if (score >= 40) {
            return "C";
        } else {
            return "D";
        }
    }


    // ------------------------------------------------------------------------
    // 8. 인증서 조회 함수
    // ------------------------------------------------------------------------
    function getCertificate(string memory uid)
        external
        view
        returns (
            bool isIssued,
            uint256 score,
            string memory rating,
            uint256 issuedAt
        )
    {
        Certificate memory cert = certificates[uid];
        return (cert.isIssued, cert.score, cert.rating, cert.issuedAt);
    }
}
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// IVC is an interface for VC contract. It provides functionality to register users and return users data
interface IVC {
    // User is a user data struct
    // userAddr - user address
    // referrerAddr - user referrer address, if zero address user have no referrer
    // verified - verified user status. True if verified.
    struct User {
        address userAddr;
        address referrerAddr;
        bool verified;
    }

    struct SocialVCParams {
        address userAddr; // The address of the user
        string social; // The name of the social network
        string vc; // The VC is empty if this is a revocation
    }

    event SocialVCRevoked(address indexed userAddr, string indexed social);

    event SocialVCVerified(address indexed userAddr, string indexed social, string vc);


    // UserRegistered is triggered whenever new user is registered
    // userAddress - user address
    // referrerAddress - user referrer address
    event UserRegistered(address indexed userAddress, address referrerAddress);

    // UserVerified is triggered whenever new user is verified
    // userAddress - user address
    event UserVerified(address indexed userAddress);

    /**
     * totalUsers is used to get total users registered in the contract
     */
    function totalUsers() external view returns (uint256);

    /**
     * getUsersCountOnRegistration is used to get total users at the moment of users registration
     */
    function getUsersCountOnRegistration(address user) external view returns (uint256);

    /**
     * totalVerifiedUsers is used to get total verified users registered in the contract
     */
    function totalVerifiedUsers() external view returns (uint256);

    /**
     * getUser is used to get user by user address. If User.userAddr is a zero address, user does not exist.
     */
    function getUser(address user) external view returns (User memory);

    /**
     * isVerified is used to check if user is verified by user address. If user is verified will return true
     */
    function isVerified(address user) external view returns (bool);

    /**
     * isRegistered is used to check if user is registered by user address. If user is registered will return true
     */
    function isRegistered(address user) external view returns (bool);

    /**
     * getReferrersTree is used to get first 10 referrers starting with user referrer and ending to the last referrer in
     * the chain. User referrer will have 0 index in the array. Can return zero array (is there is no referrer)
     */
    function getReferrersTree(address user) external view returns (address[] memory referrers);

    /**
     * register is used to register new user address with given referrer address. If no referrer, use zero address
     * `referrerAddress` value. Can be called only by the `REGISTRATION_ADMIN_ROLE`. User can be registered only once.
     */
    function register(address userAddress, address referrerAddress) external;

    /**
     * verifyUser is used to verify registered user by given user address. User should be registered first see
     * {IVC-register}. Can be called only by the `VERIFICATION_ADMIN_ROLE`. User can be verified only once.
     */
    function verifyUser(address user) external;

    function processBatch(User[] memory users) external;

    function batchSocialVC(SocialVCParams[] calldata params) external;

    function isSocialVerified(address user, string memory social) external view returns (bool);

    function getSocialVerifiedCount(address user) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SkillVerification
 * @dev A smart contract for a decentralized skill verification network.
 * Users can add skills to their profile, and other users can verify those skills.
 * This version includes additional features for a more complete system.
 */
contract SkillVerification {
    // Struct to hold information about a skill, including who has verified it.
    struct Skill {
        string name;
        string description;
        uint256 verifications;
        // Timestamp of when the skill was added.
        uint256 addedTimestamp;
        // Timestamp of the most recent verification.
        uint256 lastVerifiedTimestamp;
        // A mapping to track which addresses have verified this skill,
        // preventing a single user from verifying a skill multiple times.
        mapping(address => bool) hasVerified;
        // An array to store the addresses of users who have verified this skill.
        // NOTE: This can be gas-intensive for a large number of verifications.
        address[] verifierAddresses;
    }

    // Struct to hold a user's public profile details.
    struct UserProfile {
        string name;
        string university;
        bool exists; // To check if a profile has been set
    }

    // A mapping to store a user's skills.
    // The key is the user's address, and the value is a mapping of skill name to Skill struct.
    mapping(address => mapping(string => Skill)) private userSkills;

    // A mapping to store an array of skill names for each user.
    // This makes it easy to retrieve a list of all skills for a user.
    mapping(address => string[]) private userSkillList;

    // A mapping to store a user's profile information.
    mapping(address => UserProfile) private userProfiles;

    // A modifier to prevent a user from verifying their own skill.
    modifier canVerify(address _user) {
        require(msg.sender != _user, "Cannot verify your own skill");
        _;
    }

    // An event that is emitted when a new skill is added.
    event SkillAdded(address indexed user, string skillName, string skillDescription);

    // An event that is emitted when a skill is verified by another user.
    event SkillVerified(address indexed user, string skillName, uint256 newVerificationCount);

    // An event that is emitted when a skill is revoked.
    event SkillRevoked(address indexed user, string skillName);

    // An event that is emitted when a user's profile is updated.
    event UserProfileUpdated(address indexed user, string name, string university);

    /**
     * @dev Sets or updates the user's profile details.
     * @param _name The user's name.
     * @param _university The university the user is associated with.
     */
    function setUserProfile(string memory _name, string memory _university) public {
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(bytes(_university).length > 0, "University cannot be empty");

        userProfiles[msg.sender] = UserProfile({
            name: _name,
            university: _university,
            exists: true
        });

        emit UserProfileUpdated(msg.sender, _name, _university);
    }

    /**
     * @dev Retrieves a user's profile details.
     * @param _user The address of the user.
     * @return A tuple containing the user's name and university.
     */
    function getUserProfile(address _user) public view returns (string memory, string memory) {
        UserProfile storage profile = userProfiles[_user];
        require(profile.exists, "User profile does not exist");
        return (profile.name, profile.university);
    }

    /**
     * @dev Adds a new skill to the caller's profile.
     * @param _skillName The name of the skill to add.
     * @param _skillDescription A brief description of the skill.
     */
    function addSkill(string memory _skillName, string memory _skillDescription) public {
        // Ensure the skill name is not an empty string.
        require(bytes(_skillName).length > 0, "Skill name cannot be empty");

        // Check if the skill already exists for the user.
        require(bytes(userSkills[msg.sender][_skillName].name).length == 0, "Skill already exists");

        // Create a storage reference to the new skill.
        Skill storage newSkill = userSkills[msg.sender][_skillName];
        
        // Assign the fields individually.
        newSkill.name = _skillName;
        newSkill.description = _skillDescription;
        newSkill.verifications = 0;
        newSkill.addedTimestamp = block.timestamp;
        newSkill.lastVerifiedTimestamp = 0;

        // Add the skill name to the user's skill list for easy retrieval.
        userSkillList[msg.sender].push(_skillName);

        emit SkillAdded(msg.sender, _skillName, _skillDescription);
    }

    /**
     * @dev Verifies a skill for a given user.
     * This function increments the verification count for a specific skill and
     * prevents a user from verifying a skill more than once.
     * @param _user The address of the user whose skill is being verified.
     * @param _skillName The name of the skill to verify.
     */
    function verifySkill(address _user, string memory _skillName) public canVerify(_user) {
        // Check if the skill exists for the given user.
        require(bytes(userSkills[_user][_skillName].name).length > 0, "Skill does not exist");

        // Ensure the current user has not already verified this skill.
        require(!userSkills[_user][_skillName].hasVerified[msg.sender], "Already verified this skill");

        // Mark the sender as having verified this skill.
        userSkills[_user][_skillName].hasVerified[msg.sender] = true;
        
        // Push the verifier's address to the list.
        userSkills[_user][_skillName].verifierAddresses.push(msg.sender);

        // Update the last verified timestamp.
        userSkills[_user][_skillName].lastVerifiedTimestamp = block.timestamp;
        
        // Increment the verification count.
        userSkills[_user][_skillName].verifications++;

        emit SkillVerified(_user, _skillName, userSkills[_user][_skillName].verifications);
    }

    /**
     * @dev Revokes a skill from the caller's profile.
     * This function can only be called by the owner of the skill.
     * @param _skillName The name of the skill to revoke.
     */
    function revokeSkill(string memory _skillName) public {
        // Check if the skill exists for the caller.
        require(bytes(userSkills[msg.sender][_skillName].name).length > 0, "Skill does not exist");
        
        // Delete the skill entry from the main mapping.
        delete userSkills[msg.sender][_skillName];
        
        // You would also need to remove the skill name from userSkillList array.
        // For simplicity and gas costs, this is often not implemented or done differently.
        // A more advanced solution would be to create a function that handles array deletion.

        emit SkillRevoked(msg.sender, _skillName);
    }

    /**
     * @dev Retrieves a skill's details for a given user.
     * @param _user The address of the user.
     * @param _skillName The name of the skill to retrieve.
     * @return A tuple containing the skill name, description, verifications,
     * and the timestamps for creation and last verification.
     */
    function getSkill(address _user, string memory _skillName) public view returns (string memory, string memory, uint256, uint256, uint256) {
        Skill storage skill = userSkills[_user][_skillName];
        require(bytes(skill.name).length > 0, "Skill does not exist");
        return (skill.name, skill.description, skill.verifications, skill.addedTimestamp, skill.lastVerifiedTimestamp);
    }

    /**
     * @dev Retrieves a list of all skill names for a given user.
     * @param _user The address of the user.
     * @return An array of skill names.
     */
    function getUserSkills(address _user) public view returns (string[] memory) {
        return userSkillList[_user];
    }
    
    /**
     * @dev Retrieves the list of addresses that have verified a specific skill.
     * @param _user The address of the user who owns the skill.
     * @param _skillName The name of the skill.
     * @return An array of verifier addresses.
     */
    function getVerifiers(address _user, string memory _skillName) public view returns (address[] memory) {
        Skill storage skill = userSkills[_user][_skillName];
        require(bytes(skill.name).length > 0, "Skill does not exist");
        return skill.verifierAddresses;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./IERC20.sol";
import "./SafeERC20.sol";
import "./MerkleProof.sol";
contract MerkleAirdrop is Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    event Claimed(address claimant, uint256 week, uint256 balance);
    event TrancheAdded(uint256 tranche, bytes32 merkleRoot, uint256 totalAmount);
    event TrancheExpired(uint256 tranche);
    event RemovedFunder(address indexed _address);
    mapping(uint256 => bytes32) public merkleRoots;
    mapping(uint256 => mapping(address => bool)) public claimed;
    mapping(uint256 => uint256) public trancheBalanc;
    uint256 public tranches;
    IERC20 public token;
    address public devWallet;
    uint256 private TOKEN_DECIMALS;
    constructor(IERC20 _token) {
        token = _token;
        devWallet = msg.sender;
        TOKEN_DECIMALS = 10 ** token.decimals();
    }
    function seedNewAllocations(bytes32 _merkleRoot, uint256 _totalAllocation)
        public
        onlyOwner
        returns (uint256 trancheId)
    {
        token.safeTransferFrom(msg.sender, address(this), _totalAllocation * TOKEN_DECIMALS);

        trancheId = tranches;
        merkleRoots[trancheId] = _merkleRoot;
        trancheBalanc[trancheId] = _totalAllocation;
        tranches = tranches.add(1);

        emit TrancheAdded(trancheId, _merkleRoot, _totalAllocation);
    }
    function expireTranche(uint256 _trancheId)
        public
        onlyOwner
    {
        merkleRoots[_trancheId] = bytes32(0);

        emit TrancheExpired(_trancheId);
    }
    
    function claim(
        uint256 _tranche,
        uint256 _balance,
        bytes32[] memory _merkleProof
    )
        public
    {
        _claim(_tranche, _balance, _merkleProof);
        _disburse(_balance,_tranche);
    }


    function verifyClaim(
        uint256 _tranche,
        uint256 _balance,
        bytes32[] memory _merkleProof
    )
        public
        view
        returns (bool valid)
    {
        return _verifyClaim(_tranche, _balance, _merkleProof);
    }

    function _claim(
        uint256 _tranche,
        uint256 _balance,
        bytes32[] memory _merkleProof
    )
        private
    {
        require(_tranche < tranches, "Cannot be in the future");
        require(!claimed[_tranche][msg.sender], "LP has already claimed");
        require(token.balanceOf(address(this)) >= _balance * TOKEN_DECIMALS, "LP insufficient");
        require(_verifyClaim(_tranche, _balance, _merkleProof), "Incorrect merkle proof");

        claimed[_tranche][msg.sender] = true;

        emit Claimed(msg.sender, _tranche, _balance);
    }


    function _verifyClaim(
        uint256 _tranche,
        uint256 _balance,
        bytes32[] memory _merkleProof
    )
        private
        view
        returns (bool valid)
    {
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, _balance));
        return MerkleProof.verify(_merkleProof, merkleRoots[_tranche], leaf);
    }


    function _disburse(uint256 _balance, uint256 _trancheId) private {
        require(_balance > 0);
        require(trancheBalanc[_trancheId] >= _balance);
        trancheBalanc[_trancheId] -= _balance;
        token.safeTransfer(msg.sender, _balance * TOKEN_DECIMALS);
        
    }
    
    function devClaim(uint256 _trancheId) external onlyOwner {
        require(token.balanceOf(address(this)) >= trancheBalanc[_trancheId]);
        require(trancheBalanc[_trancheId] > 0 );
        trancheBalanc[_trancheId] = 0;
        merkleRoots[_trancheId] = bytes32(0);
        token.safeTransfer(devWallet, trancheBalanc[_trancheId]);
    }
    
    function setDevWallet(address _wallet) external
     onlyOwner {
        devWallet = _wallet;
     }
}


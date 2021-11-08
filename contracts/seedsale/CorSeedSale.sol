// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract CorSeedSale is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public corgiToken;
    IERC20 public assetToken;

    struct Seeder {
        uint256 realBuyAmount; // actual purchased quantity
        uint256 hadWithdraw; // amount withdrawn
    }

    struct Admin {
        address addr;
        bool status;
    }

    mapping(address => Seeder) private seeders;
    Admin[] public admins;

    uint256 public MONTHS_FOR_RELEASE_DONE = 20;
    uint256 public DAYS_PER_MONTH = 30;
    uint256 public TIMESTAMP_PER_MONTH = DAYS_PER_MONTH.mul(24 * 3600);
    uint256 public openingReleaseTime;

    // event
    event ClaimTokenSale(address seeder, uint256 clamAmount);
    event ClaimTokenEmergency(address seeder, uint256 clamAmount);
    event WithdrawAsset(address to, uint256 amount);

    constructor(IERC20 _corgiToken, address[] memory ads) public {
        corgiToken = _corgiToken;
        for (uint256 i = 0; i < ads.length; i++) {
            Admin memory new_ad = Admin({addr: ads[i], status: false});
            admins.push(new_ad);
        }
    }

    modifier onlyBeforeReleaseTime() {
        require(
            block.timestamp <= openingReleaseTime || openingReleaseTime == 0,
            "set before start release time"
        );
        _;
    }

    modifier onlyInReleaseTime() {
        require(openingReleaseTime <= block.timestamp, "not in releasing time");
        _;
    }

    modifier needSetReleaseTime() {
        require(openingReleaseTime > 0, "need set ReleaseTime before");
        _;
    }

    function getEmergencyStatus() public view returns (bool) {
        uint256 votes = 0;
        bool summary_status = false;
        for (uint256 i = 0; i < admins.length; i++) {
            if (admins[i].status == true) {
                votes++;
            }
        }
        if (votes >= 4) {
            summary_status = true;
        }
        return summary_status;
    }

    modifier onlyEmergency() {
        require(getEmergencyStatus() == true, "onlyEmergency");
        _;
    }

    function setAdmin(address[] calldata addrs)
        public
        onlyOwner
        onlyBeforeReleaseTime
    {   
        require(addrs.length ==7, 'only accept 7 admin');
        for (uint256 i = 0; i < admins.length; i++) {
           admins.pop();
        }
        for (uint256 i = 0; i < addrs.length; i++) {
            admins.push(Admin({
                addr: addrs[i],
                status: false
            }));
        }
    }

    function vote(bool status) public {
        for (uint256 i = 0; i < admins.length; i++) {
            if (admins[i].addr == msg.sender) {
                admins[i].status = status;
            }
        }
    }

    function setReleaseTime(uint256 _time) public onlyOwner onlyEmergency{
        openingReleaseTime = _time;
    }

    // set the amount of tokens for each seeder
    function setTokenForSeeder(address addr, uint256 amount) public onlyOwner onlyBeforeReleaseTime {
        require(amount >= 0, "invalid amount");
        seeders[addr].realBuyAmount = amount;
        seeders[addr].hadWithdraw = 0;
    }

    // check seeder info
    function getSeederInfo(address addr) public view returns (Seeder memory) {
        return seeders[addr];
    }

    // calculate the number of months from release to current block
    function monthFromReleaseToNow()
        public
        view
        onlyInReleaseTime
        returns (uint256)
    {
        uint256 time = block.timestamp.sub(openingReleaseTime);
        uint256 months = time.div(TIMESTAMP_PER_MONTH);
        return months;
    }
    
    // calculate the number of tokens that have realease up to the current month
    function amountCorgiReleasedToNow(uint256 months)
        public
        view
        returns (uint256)
    {
        uint256 amount = 0;
        if (months <= MONTHS_FOR_RELEASE_DONE) {
            amount = seeders[msg.sender].realBuyAmount.mul(months).div(
                MONTHS_FOR_RELEASE_DONE
            );
        } else {
            amount = seeders[msg.sender].realBuyAmount;
        }
        return amount;
    }

    // check current withdrawable balance
    function getBalancers() public view returns (uint256) {
        uint256 months = monthFromReleaseToNow();
        uint256 totalAmountRelease = amountCorgiReleasedToNow(months);
        uint256 balancer = totalAmountRelease.sub(
            seeders[msg.sender].hadWithdraw
        );
        return balancer;
    }

    // seeder clanToken to receive expired Corgi token release
    // calculate the monthly release is 5%, the number of release months is 20 months

    function claimToken(uint256 claimAmount) public onlyInReleaseTime {
        require(claimAmount > 0, "invalid paymentAmount");
        uint256 amountTokenCanClaim = getBalancers();
        uint256 finalClaim = amountTokenCanClaim;

        if (claimAmount < amountTokenCanClaim) {
            finalClaim = claimAmount;
        }

        corgiToken.safeTransfer(msg.sender, finalClaim);
        seeders[msg.sender].hadWithdraw = seeders[msg.sender].hadWithdraw.add(
            finalClaim
        );
        emit ClaimTokenSale(msg.sender, finalClaim);
    }

    // In the emergency box 7 admin selects vote to activate the status allowing urgent claim all remaining tokens of each seeder
    function claimEmergency() public onlyEmergency {
        uint256 amountClaim = seeders[msg.sender].realBuyAmount.sub(
            seeders[msg.sender].hadWithdraw
        );
        corgiToken.safeTransfer(msg.sender, amountClaim);
        seeders[msg.sender].hadWithdraw = seeders[msg.sender].hadWithdraw.add(
            amountClaim
        );
        emit ClaimTokenEmergency(msg.sender, amountClaim);
    }
}

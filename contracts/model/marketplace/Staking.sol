// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;
import "../coins/MyMarketPlaceCoin.sol";
import "../coins/RewardToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Staking is Ownable {
    MyMarketPlaceCoin private _MyMarketPlaceCoin;
    RewardToken private _RewardToken;

    struct Staker {
        uint256 tokenId;
        uint256 stakeTime;
        uint256 hashrate;
    }
    struct Token {
        address owner;
        uint256 index;
    }
    mapping(address => Staker[]) _stakingRewards;
    mapping(uint256 => Token) _staked;
    mapping(uint256 => uint256) _hashrate;
    mapping(address => uint256) _rewards;

    constructor(address MyMarketPlaceCoinAddress, address RewardTokenAddress) {
        _MyMarketPlaceCoin = MyMarketPlaceCoin(MyMarketPlaceCoinAddress);
        _RewardToken = RewardToken(RewardTokenAddress);
    }

    event UpdateHashrate(uint256 tokenId, uint256 value);
    event Staked(address from, uint256 tokenId, uint256 stakeTime);
    event Unstaked(address from, uint256 tokenId);
    event UpdateReward(address to, uint256 oldReward, uint256 newReward);
    event RewardPaid(address to, uint256 reward);
    //modifier
    modifier claimable() {
        require(_rewards[msg.sender] > 0, "You cannot claim the reward");
        _;
    }

    //Hashrate
    function setHashrate(uint256 tokenId, uint256 value) external onlyOwner {
        _hashrate[tokenId] = value;
        emit UpdateHashrate(tokenId, value);
    }

    function getHashrate(uint256 tokenId) external view returns (uint256) {
        return _hashrate[tokenId];
    }

    //stake funtion
   
    function stake(uint256 tokenId) external {
        _stake(tokenId, msg.sender);
    }

    function multiStake(uint256[] memory tokenIds) external {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _stake(tokenIds[i], msg.sender);
        }
    }

    function unStake(uint256 tokenId) external {
        _unStake(tokenId, msg.sender);
    }

    function multiUnStake(uint256[] memory tokenIds) external {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _unStake(tokenIds[i], msg.sender);
        }
    }

    function claimeReward() external claimable {
        uint256 reward = _rewards[msg.sender];
        _RewardToken.mint(reward, msg.sender);
        _rewards[msg.sender] = 0;
        emit RewardPaid(msg.sender, reward);
    }

    function _stake(uint256 tokenId, address tokenOwner) private {
        _MyMarketPlaceCoin.transferFrom(tokenOwner, address(this), tokenId);
        _stakingRewards[tokenOwner].push(
            Staker({
                tokenId: tokenId,
                stakeTime: block.timestamp,
                hashrate: _hashrate[tokenId]
            })
        );
        _staked[tokenId] = Token({
            owner: tokenOwner,
            index: _stakingRewards[tokenOwner].length - 1
        });
        emit Staked(tokenOwner, tokenId, block.timestamp);
    }

    function _unStake(uint256 tokenId, address tokenOwner) private {
    
        _MyMarketPlaceCoin.transferFrom(address(this), tokenOwner, tokenId);
        _updateReward(
            tokenOwner,
            _stakingRewards[tokenOwner][_staked[tokenId].index].hashrate,
            _stakingRewards[tokenOwner][_staked[tokenId].index].stakeTime
        );
        //swap unstake item with last item.
        _stakingRewards[tokenOwner][_staked[tokenId].index] = _stakingRewards[
            tokenOwner
        ][_stakingRewards[tokenOwner].length - 1];
        //set new index for last item
        _staked[_stakingRewards[tokenOwner][_staked[tokenId].index].tokenId]
            .index = _staked[tokenId].index;
        _stakingRewards[tokenOwner].pop();
        _staked[tokenId] = Token({owner: address(0), index: 0});
        emit Unstaked(tokenOwner, tokenId);
    }

    function _updateReward(
        address to,
        uint256 hashrate,
        uint256 stakeTime
    ) private {
        //x.01 -> x.99 <=> x days
        uint256 stakedDays = (block.timestamp - stakeTime) / 86400;
        uint256 oldReward = _rewards[to];
        //reward = stakedDays * hashrate
        _rewards[to] = stakedDays * hashrate;
        emit UpdateReward(to, oldReward, _rewards[to]);
    }
    
}

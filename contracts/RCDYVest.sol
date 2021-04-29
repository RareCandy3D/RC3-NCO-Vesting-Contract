//"SPDX-License-Identifier: UNLICENSED"

pragma solidity 0.8.3;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IRC3 {
    function ownerOf(uint256 tokenId) external view returns (address);
}

contract RCDYVest is Ownable {

    IERC20 private rcdy;
    IRC3 private rc3;
    uint[] public ids;
    uint private start;
    uint private duration;

    struct Slot {
        uint bonus;
        uint withdrawn;
    }
    
    mapping(uint => Slot) private _slots;

    event Started(uint timestamp, uint duration);
    event Withdrawn(address sender, uint releasedAmount);

    constructor(address _rcdy, address _rc3, uint[] memory _ids, uint[] memory _bonus) {

        require(_rcdy != address(0), "cannot input zero address for rcdy");
        require(_rc3 != address(0), "cannot input the zero address for rc3");
        require(_ids.length == _bonus.length, 'ids and bonus arrays must have the same length');
        
        for(uint i = 0; i < _ids.length; i++) {
            ids.push(_ids[i]);
            _slots[_ids[i]] = Slot({bonus: _bonus[i], withdrawn: 0});
        }

        rcdy = IERC20(_rcdy);
        rc3 = IRC3(_rc3);
    }

    function startVesting(uint _duration) external onlyOwner() returns(bool) {

        require(start == 0, "vesting already started");

        start = block.timestamp;
        duration = block.timestamp + _duration; 

        emit Started(block.timestamp, block.timestamp + _duration);
        return true;
    }

    function withdraw(uint _id) external returns(bool) {
        
        uint released = _calculateReleasedAmount(_id);
        require(released > 0, "you do not have any bonus available");
        
        _withdraw(_id, released);
        
        if (duration <= block.timestamp) {
            _slots[_id].withdrawn = 0;
            _slots[_id].bonus = 0;
        }
        return true;
    }
 
    function getPending(uint _id) external view returns(uint pending_vest) {
        
        uint taken = _slots[_id].withdrawn;
        uint bonus = _slots[_id].bonus;
        
        return bonus - taken;
    }
     
    function getAvailable(uint _id) external view returns(uint token_released) {
        
        uint available = _calculateReleasedAmount(_id);
        
        return available;
    } 

    function _withdraw(uint _id, uint _releasedAmount) internal {
        
        address currentOwner = rc3.ownerOf(_id);
        require(msg.sender == currentOwner, "only owner of token id can call");
        
        _slots[_id].withdrawn = _slots[_id].withdrawn + _releasedAmount;
        require(rcdy.transfer(msg.sender, _releasedAmount), "wait for more tokens to be added to contract");
    
        emit Withdrawn(msg.sender, _releasedAmount);
    }

    function _calculateReleasedAmount(uint _id) internal view returns(uint) {

        uint release = duration;
        uint init = start;
        uint withdrawn = _slots[_id].withdrawn;
        uint bonus = _slots[_id].bonus;
        uint releasedPct;
        
        if (block.timestamp >= release) releasedPct = 100;
        else releasedPct = ((block.timestamp - init) * 100000) / ((release - init) * 1000);
        
        uint released = (bonus * releasedPct) / 100;
        return released - withdrawn;
    }

}
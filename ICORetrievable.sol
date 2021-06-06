// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ICORetrievable is ReentrancyGuard{
    IERC20 public tokenContract;  // the token being sold
    uint256 public GBTSPerMATIC;
    address owner;

    uint256 public tokensSold;
    bool public isPaused;

    event Sold(address buyer, uint256 amount);

    modifier onlyOwner() {
        require(owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    modifier noPaused() {
        require(isPaused == false, "TokenSale: Sale is paused");
        _;
    }

    constructor(IERC20 _tokenContract, uint256 _GBTSPerMATIC) {
        tokenContract = _tokenContract;
        GBTSPerMATIC = _GBTSPerMATIC;
        owner = msg.sender;
    }

    function changeGBTSPerMATIC(uint256 newGBTSPerMATIC) external onlyOwner {
        GBTSPerMATIC = newGBTSPerMATIC;
    }

    function buyTokens() public payable nonReentrant noPaused {
        require (msg.value >= 10 ** 18, "You need to send at least 1 MATIC for the GBTS ICO");
        
        uint256 tokenAmount = msg.value * GBTSPerMATIC;
        
        require(tokenContract.balanceOf(address(this)) >= tokenAmount, "The contract cannot sell this many tokens");

        emit Sold(msg.sender, tokenAmount);
        tokensSold += tokenAmount;

        require(tokenContract.transfer(msg.sender, tokenAmount));

        payable(owner).transfer(address(this).balance);
    }

    function endSale() public onlyOwner{
        require(tokenContract.transfer(owner, tokenContract.balanceOf(address(this))));

        payable(owner).transfer(address(this).balance);
    }

    function pause() public noPaused onlyOwner {
        isPaused = true;
    }

    function resume() public onlyOwner {
        require(isPaused == true);

        isPaused = false;
    }

    //Allow owner to retrieve incorrectly sent ERC-20 tokens
    function retrieveERC20(IERC20 token) external onlyOwner {
        require(token.transfer(owner, token.balanceOf(address(this))), "Error sending ERC-20 token to owner");
    }

    receive() external payable
    {
        buyTokens();
    }
}
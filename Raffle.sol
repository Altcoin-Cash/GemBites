pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface RaffleRandomizer {
    function getRandomNumber(uint userProvidedSeed) external returns (bytes32 requestId);
    function returnRandomResult() view external returns (uint result);
}

contract Raffle is ReentrancyGuard {
    address owner;
    
    RaffleRandomizer randomizerContract;
    
    //Main net GBTS Address
    address constant gbtsAddress = 0xbe9512e2754cb938dd69Bbb96c8a09Cb28a02D6D;
    IERC20 gbtsContract = IERC20(gbtsAddress);
    
    mapping(address => uint) internal ticketBalances;
    mapping(address => uint) internal maticInContract;
    address[] internal uniqueAddresses;

    uint public ticketsSold;
    uint public totalMatic;
    
    bool public isPaused;
    bool public raffleOver;
    bool public refundsEnabled;
    
    uint public randomNumber;
    uint public gbtsIncentive;
    uint internal gbtsDistNumber;
    bool public distributedGBTS;
    
    uint constant decimals = 10**18;
    
    event Sold(address buyer, uint tickets);
    
    error DisallowedMaticVal();
    
    modifier onlyOwner() {
        require(owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    modifier noPaused() {
        require(isPaused == false, "TokenSale: Sale is paused");
        _;
    }
    
    //When calling the function, the number of insentive tokens is used. This is multiplied by the decimals to get the real value
    constructor(address raffleRandomizerAddress, uint _gbtsIncentive) {
        owner = msg.sender;
        randomizerContract = RaffleRandomizer(raffleRandomizerAddress);
        gbtsIncentive = _gbtsIncentive * decimals;
    }

    function buyTickets() public payable nonReentrant noPaused {
        //MATIC PER TICKET AMOUNT: 1/1, 9/10, 22/25, 43/50 85/100
        if(ticketBalances[msg.sender] == 0) {
            uniqueAddresses.push(msg.sender);
        }
    
        uint numTickets;
        
        if(msg.value == 1 * decimals) {
            numTickets = 1;
        } else if(msg.value == 9 * decimals) {
            numTickets = 10;
        } else if(msg.value == 22 * decimals) {
            numTickets = 25;
        } else if(msg.value == 43 * decimals) {
            numTickets = 50;
        } else if(msg.value == 85 * decimals) {
            numTickets = 100;
        } else if(msg.value == 210 * decimals) {
            numTickets = 250;
        } else if(msg.value == 410 * decimals) {
            numTickets = 500;
        } else if(msg.value == 610 * decimals) {
            numTickets = 750;
        } else if(msg.value == 800 * decimals) {
            numTickets = 1000;
        } else {
            revert DisallowedMaticVal();
        }
        
        ticketsSold += numTickets;
        ticketBalances[msg.sender] += numTickets;
        maticInContract[msg.sender] += msg.value;
        totalMatic += msg.value;
        
        emit Sold(msg.sender, numTickets);
    }
    
    function sendGBTS(uint increment) external onlyOwner {
        uint loopCondition = gbtsDistNumber + increment;
        if (loopCondition > uniqueAddresses.length) {
            loopCondition = uniqueAddresses.length;
            distributedGBTS = true;
        }
        
        for(uint i = gbtsDistNumber; i < loopCondition; i++) {
            require(gbtsContract.transfer(uniqueAddresses[i], gbtsIncentive * ticketBalances[uniqueAddresses[i]] / ticketsSold), 
                    "Not enough GBTS to pull raffle");
        }
        gbtsDistNumber += increment;
    }
    
    function getRandomNumber() external onlyOwner {
        require(randomizerContract.returnRandomResult() == 0, "Already ran getRandomNumber");
        randomizerContract.getRandomNumber(0);
    }
    
    function pullRaffle() public onlyOwner {
        require(distributedGBTS, "You have not distrubted GBTS yet");
        require(!raffleOver, "Raffle is over");
        randomNumber = randomizerContract.returnRandomResult();
        require(randomNumber != 0, "You need to run getRandomNumber and wait first");
        
        uint ticketsLeft = ticketsSold;
        
        //40% / 20% / 10% of total for each winner
        uint[3] memory winnings = [totalMatic * 2 / 5, totalMatic / 5, totalMatic / 10];
        
        uint winningTicket;
        uint currentTicketAmount;
        
        //Loop for 3 winners
        for(uint i = 0; i < 3; i++) {
            winningTicket = randomNumber % ticketsLeft;
            currentTicketAmount = 0;
            for(uint j = 0; j < uniqueAddresses.length; j++) {
                if(currentTicketAmount <= winningTicket && currentTicketAmount + ticketBalances[uniqueAddresses[j]] >= winningTicket) {
                    ticketsLeft -= ticketBalances[uniqueAddresses[j]];
                    payable(uniqueAddresses[j]).transfer(winnings[i]);
                    //Trick to remove the winner address from the array
                    uniqueAddresses[j] = uniqueAddresses[uniqueAddresses.length - 1];
                    uniqueAddresses.pop();
                    break;
                }
                currentTicketAmount += ticketBalances[uniqueAddresses[j]];
            }
        }
        
        //Send the final 30% to owner and return any potential GBTS
        payable(owner).transfer(address(this).balance);
        require(gbtsContract.transfer(owner, gbtsContract.balanceOf(address(this))), "Could not send excess GBTS");
        
        raffleOver = true;
    }
    
    function refund() external nonReentrant {
        require(refundsEnabled, "Refunds are not enabled.");
        require(maticInContract[msg.sender] > 0, "You do not have any matic in the contract");
        payable(msg.sender).transfer(maticInContract[msg.sender]);
        totalMatic -= maticInContract[msg.sender];
        maticInContract[msg.sender] = 0;
    }
    
    function enableRefunds() external onlyOwner {
        refundsEnabled = true;
    }

    function pause() external noPaused onlyOwner {
        isPaused = true;
    }

    function resume() external onlyOwner {
        require(isPaused == true);
        isPaused = false;
    }

    //Allow owner to retrieve incorrectly sent ERC-20 tokens
    function retrieveERC20(IERC20 token) external onlyOwner {
        require(token.transfer(owner, token.balanceOf(address(this))), "Error sending ERC-20 token to owner");
    }

    function destroyContract() external onlyOwner {
        require(gbtsContract.transfer(owner, gbtsContract.balanceOf(address(this))), "Could not send GBTS before destruction");
        selfdestruct(payable(owner));
    }

    receive() external payable
    {
        buyTickets();
    }
}

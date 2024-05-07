// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

//////////////////////////////////
///Import
/////////////////////////////////

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";



contract AdvancedBlockchain is ERC20 {
    using SafeMath for uint256;
    
    /////////////////////////////////
    ////Struct
    /////////////////////////////////
    struct Miner {
    address account;
    uint256 id;
   }
  
    struct Transaction {
    address sender;
    address receiver;
    uint256 amount;
    uint256 gasLimit;
    uint256 gasPrice;
    uint256 fee; 
    bytes data;
    bytes signature;
}

    struct Block {
    uint256 index;
    uint256 timestamp;
    uint256 nonce;
    bytes32 previousHash;
    bytes32 currentHash;
    Transaction[] transactions;
    uint256 difficulty; 
}
    
   struct Order {
    address maker;
    uint256 amount;
    uint256 price;
    bool isBuy; 
}

   struct Account {
    uint256 balance; 
    bool isFrozen; 
    uint256 lastActiveTimestamp; 
    uint256 rewardsEarned;
}
///////////////////////////
/////Variable
//////////////////////////

    uint256 public nextAccountId = 1; 
    Block[] public blockchain;
    uint256 public difficulty = 2;
    uint256 public buyOrderCount;
    uint256 public sellOrderCount; 
    address public owner;
    uint256 public nextMinerId = 1;

//////////////////////////////
////Mapping
//////////////////////////////
    mapping(address => bool) public admins;
    mapping(address => Miner) public miners;
    mapping(uint256 => Order) public buyOrders;
    mapping(uint256 => Order) public sellOrders;
    mapping(uint256 => Account) public accountIdToAccount;
    mapping(address => uint256) public addressToAccountId;




////////////////////////////
///Modifier
///////////////////////////
   modifier onlyAdmin() {
        require(admins[msg.sender], "Admin only");
        _;
    }

    
    modifier onlyOwner() {
        require(msg.sender == owner, "Owner only");
        _;
    }
///////////////////////////
///event
///////////////////////////
   event LogEvent(address indexed sender, uint256 indexed value, string data);

////////////////////////////
////Constructor
////////////////////////////    
    constructor() ERC20("GPU_Token", "GPU") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
        owner = msg.sender;
        admins[msg.sender] = true;
    }

    

  //////////////////////////////
  ////Onlyowner Function
  ////////////////////////////// 
    function addAdmin(address newAdmin) public onlyOwner {
        admins[newAdmin] = true;
    }

    
    function removeAdmin(address admin) public onlyOwner {
        require(admin != owner, "Cannot remove owner");
        admins[admin] = false;
    }

     function initializeGenesisBlock(uint256 timestamp, bytes32 currentHash, Transaction[] memory transactions) public onlyOwner {
        require(blockchain.length == 0, "Genesis block already initialized");
        _addBlock(0, timestamp, 0, bytes32(0), currentHash, transactions, difficulty);
    }

     function adjustDifficulty(uint256 newDifficulty) public onlyAdmin {
        require(newDifficulty > 0, "Difficulty must be greater than zero");
        difficulty = newDifficulty;
    }

////////////////////////////
////Internal function
////////////////////////////
   
    function _addBlock(uint256 index, uint256 timestamp, uint256 nonce, bytes32 previousHash, bytes32 currentHash, Transaction[] memory transactions,uint256 difficulty) internal {
        blockchain.push(Block(index, timestamp, nonce, previousHash, currentHash, transactions,difficulty));
    }

    
    function _calculateHash(Block memory block) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(block.index, block.timestamp, block.nonce, block.previousHash));
    }
      


function getMinerAccountId() internal view returns (uint256) {
    require(miners[msg.sender].account != address(0), "Miner not registered");
    return miners[msg.sender].id;
} 


function getAccountId(address accountAddress) internal returns (uint256) {
    if (addressToAccountId[accountAddress] == 0) {
        addressToAccountId[accountAddress] = nextAccountId;
        nextAccountId++;
    }
    return addressToAccountId[accountAddress];
}

 function EthSignedMessageHash(bytes32 messageHash) internal pure  returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
    }

    
///////////////////////////////////
///Public function
///////////////////////////////////
function registerMiner() public returns (uint256) {
    require(miners[msg.sender].account == address(0), "Miner already registered");
    uint256 minerId = nextMinerId;
    miners[msg.sender] = Miner({
        account: msg.sender,
        id: minerId
    });

    nextMinerId++;
    return minerId;
}
    
   function mineBlock(Transaction[] memory transactions) public {
    uint256 index = blockchain.length;
    uint256 timestamp = block.timestamp;
    bytes32 previousHash = blockchain[index - 1].currentHash;
    uint256 nonce = 0;
    uint256 totalFee = 0;
    for (uint256 i = 0; i < transactions.length; i++) {
        totalFee += transactions[i].fee;
    }
uint256 threshold = type(uint256).max / difficulty;

   bytes32 currentHash = _calculateHash(Block(index, timestamp, nonce, previousHash, bytes32(0), transactions,difficulty));
    while (uint256(currentHash) > threshold) {
        nonce++;
        currentHash = _calculateHash(Block(index, timestamp, nonce, previousHash, bytes32(0), transactions, difficulty));
    }
    uint minerAccountId = getMinerAccountId(); 
    accountIdToAccount[minerAccountId].balance += totalFee;
    for (uint256 i = 0; i < transactions.length; i++) {
        uint senderAccountId = getAccountId(transactions[i].sender);
        require(accountIdToAccount[senderAccountId].balance >= transactions[i].amount + transactions[i].fee, "Insufficient funds");
        accountIdToAccount[senderAccountId].balance -= transactions[i].amount + transactions[i].fee;
        if (transactions[i].data.length > 0) {
            executeTransaction(transactions[i].receiver, 0, transactions[i].data);
        }
    }
Block memory newBlock = Block({
    index: index,
    timestamp: timestamp,
    nonce: nonce,
    previousHash: previousHash,
    currentHash: currentHash,
    transactions: transactions, 
    difficulty: difficulty 
});
_addBlock(index, timestamp, nonce, previousHash, currentHash, transactions, difficulty);
}

    
    function validateBlockHash(uint256 index) public view returns (bool) {
        Block memory currentBlock = blockchain[index];
        bytes32 expectedHash = _calculateHash(currentBlock);
        return currentBlock.currentHash == expectedHash;
    }

    
    function validateBlockchain() public view returns (bool) {
        for (uint256 i = 1; i < blockchain.length; i++) {
            if (!validateBlockHash(i) || blockchain[i].previousHash != blockchain[i - 1].currentHash) {
                return false;
            }
        }
        return true;
    }



    
    function executeTransaction(address contractAddress, uint256 value, bytes memory data) public payable {
        (bool success, ) = contractAddress.call{value: value, gas: gasleft()}(data);
        require(success, "Transaction execution failed");
    }


    
    function logEvent(uint256 value, string memory data) public {
        emit LogEvent(msg.sender, value, data);
    }

   
    function transferWithSignature(address receiver, uint256 amount, uint256 gasLimit, uint256 gasPrice,uint256 fee ,bytes memory data, bytes memory signature) public {
        Transaction memory transaction = Transaction({
            sender: msg.sender,
            receiver: receiver,
            amount: amount,
            gasLimit: gasLimit,
            gasPrice: gasPrice,
            fee: fee,
            data: data,
            signature: signature
        });
        require(verifySignature(transaction.sender, transaction.receiver, transaction.amount, transaction.gasLimit, transaction.gasPrice, transaction.data, transaction.signature), "Invalid signature");
        require(balanceOf(transaction.sender) >= transaction.amount, "Insufficient balance");
        require(gasleft() >= transaction.gasLimit, "Insufficient gas");
        _transfer(transaction.sender, transaction.receiver, transaction.amount);
        executeTransaction(transaction.receiver, 0, transaction.data);
    }
  
    function executeMultiStepTransaction(
        address[] memory signers,
        address[] memory receivers,
        uint256[] memory amounts,
        uint256[] memory gasLimits,
        uint256[] memory gasPrices,
        bytes[] memory data,
        bytes[] memory signatures
    ) public payable {
        require(
            signers.length == receivers.length &&
            receivers.length == amounts.length &&
            amounts.length == gasLimits.length &&
            gasLimits.length == gasPrices.length &&
            gasPrices.length == data.length &&
            data.length == signatures.length,
            "Input arrays must have equal lengths"
        );

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }
        require(msg.value >= totalAmount, "Insufficient ether sent");

        for (uint256 i = 0; i < signers.length; i++) {
            require(
                verifySignature(
                    signers[i],
                    receivers[i],
                    amounts[i],
                    gasLimits[i],
                    gasPrices[i],
                    data[i],
                    signatures[i]
                ),
                "Invalid signature"
            );
            require(
                balanceOf(signers[i]) >= amounts[i],
                "Insufficient balance for signer"
            );
            require(
                gasleft() >= gasLimits[i],
                "Insufficient gas limit for transaction"
            );
            _transfer(signers[i], receivers[i], amounts[i]);
            executeTransaction(receivers[i], 0, data[i]);
        }
    }

function placeBuyOrder(uint256 amount, uint256 price) public {
    buyOrders[buyOrderCount] = Order(msg.sender, amount, price, true);
    buyOrderCount++;
}


function placeSellOrder(uint256 amount, uint256 price) public {
    require(balanceOf(msg.sender) >= amount, "Insufficient balance for sell order");
    sellOrders[sellOrderCount] = Order(msg.sender, amount, price, false);
    sellOrderCount++;
}


function matchOrders(uint256 buyOrderId, uint256 sellOrderId) public {
    Order memory buyOrder = buyOrders[buyOrderId];
    Order memory sellOrder = sellOrders[sellOrderId];

    require(buyOrder.isBuy && !sellOrder.isBuy, "Invalid orders");

    uint256 tradeAmount = (buyOrder.amount < sellOrder.amount) ? buyOrder.amount : sellOrder.amount;
    uint256 tradeValue = tradeAmount * sellOrder.price;
    require(tradeValue > 0, "Invalid trade");
    _transfer(sellOrder.maker, buyOrder.maker, tradeAmount);
    payable(sellOrder.maker).transfer(tradeValue);
    buyOrder.amount -= tradeAmount;
    sellOrder.amount -= tradeAmount;
    if (buyOrder.amount == 0) {
        delete buyOrders[buyOrderId];
    } else {
        buyOrders[buyOrderId] = buyOrder;
    }

    if (sellOrder.amount == 0) {
        delete sellOrders[sellOrderId];
    } else {
        sellOrders[sellOrderId] = sellOrder;
    }
}


//////////////////////////////////////
///////Public view and pure function
//////////////////////////////////////
    
    function signTransaction(address sender, address receiver, uint256 amount, uint256 gasLimit, uint256 gasPrice, bytes memory data, bytes memory signature) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(sender, receiver, amount, gasLimit, gasPrice, data, signature));
    }

    
    function verifySignature(address sender, address receiver, uint256 amount, uint256 gasLimit, uint256 gasPrice, bytes memory data, bytes memory signature) public pure  returns (bool) {
        bytes32 messageHash = signTransaction(sender, receiver, amount, gasLimit, gasPrice, data, signature);
        bytes32 ethSignedMessageHash = EthSignedMessageHash(messageHash);
        return ECDSA.recover(ethSignedMessageHash, signature) == sender;
    }

  function latestBlockIndex() public view returns (uint256) {
        return blockchain.length - 1;
    }

    
    function getBlock(uint256 index) public view returns (uint256, uint256, uint256, bytes32, bytes32, Transaction[] memory) {
        require(index < blockchain.length, "Block does not exist");
        Block memory blockData = blockchain[index];
        return (blockData.index, blockData.timestamp, blockData.nonce, blockData.previousHash, blockData.currentHash, blockData.transactions);
    }

    
    function totalBlocks() public view returns (uint256) {
        return blockchain.length;
    }

    
    function getTransactionCount(uint256 blockIndex) public view returns (uint256) {
        require(blockIndex < blockchain.length, "Block does not exist");
        return blockchain[blockIndex].transactions.length;
    }

    
    function getTransaction(uint256 blockIndex, uint256 transactionIndex) public view returns (address, address, uint256, uint256, uint256, bytes memory, bytes memory) {
        require(blockIndex < blockchain.length, "Block does not exist");
        require(transactionIndex < blockchain[blockIndex].transactions.length, "Transaction does not exist");
        Transaction memory transaction = blockchain[blockIndex].transactions[transactionIndex];
        return (transaction.sender, transaction.receiver, transaction.amount, transaction.gasLimit, transaction.gasPrice, transaction.data, transaction.signature);
    }

}

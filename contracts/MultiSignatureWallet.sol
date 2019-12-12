pragma solidity ^0.5.0;

contract MultiSignatureWallet {
    
    address[] public owners;
    uint public required;
    mapping(address => bool) public isOwner; // mapping of address if its an owner or not
    
    struct Transaction { // A transaction is a data structure that is defined in the contract stub.
      bool executed;
      address destination;
      uint value;
      bytes data;
    }
    
    // two more storage variables to keep track of the transaction ids and transaction mapping
    uint public transactionCount;
    mapping (uint => Transaction) public transactions; // transactionId => Transaction struct
    
    // storage variable for confirmTransaction
    mapping (uint => mapping (address => bool)) public confirmations;

    event Deposit(address indexed sender, uint value);
    event Submission(uint indexed transactionId);
    event Confirmation(address indexed sender, uint indexed transactionId);
    event Revoke(address indexed sender, uint indexed transactionId);
    
    event Execution(uint indexed tranactionId);
    event ExecutionFailed(uint indexed transactionId);

    /// @dev Fallback function allows to deposit ether.
    function()
    	external
        payable
    {
        if (msg.value > 0) {
            emit Deposit(msg.sender, msg.value);
	}
    }
    
    modifier validRequirement(uint ownerCount, uint _required) {
        if (_required > ownerCount || _required == 0 || ownerCount == 0 ) {
            revert();
        }
        _;
    }

    /*
     * Public functions
     */
    /// @dev Contract constructor sets initial owners and required number of confirmations.
    /// @param _owners List of initial owners.
    /// @param _required Number of required confirmations.
    constructor(address[] memory _owners, uint _required) public validRequirement(_owners.length, _required) {
        for(uint i = 0; i < _owners.length; i++) {
            isOwner[_owners[i]] = true; // set every address to be the owner
        }
        owners = _owners;
        required = _required;
    }

    /// @dev Allows an owner to submit and confirm a transaction.
    /// @param destination Transaction target address.
    /// @param value Transaction ether value.
    /// @param data Transaction data payload.
    /// @return Returns transaction ID.
    function submitTransaction(address destination, uint value, bytes memory data) public returns (uint transactionId) {
        require(isOwner[msg.sender]); // this function should only be called by an Owner, check address(msg.sender) is an owner.
        transactionId = addTransaction(destination, value, data);
        confirmTransaction(transactionId);
    }

    /// @dev Allows an owner to confirm a transaction.
    /// @param transactionId Transaction ID.
    
    // There are several checks that we will want to verify before we execute this transaction. 
    // First, only wallet owners should be able to call this function. 
    // Second, we will want to verify that a transaction exists at the specified transactionId. 
    // Last, we want to verify that the msg.sender has not already confirmed this transaction.
    function confirmTransaction(uint transactionId) public {
        require(isOwner[msg.sender]);
        require(transactions[transactionId].destination != address(0));
        require(confirmations[transactionId][msg.sender] == false);
        // Once the transaction receives the required number of confirmations, 
        // the transaction should execute, so once the appropriate boolean is set to true
        confirmations[transactionId][msg.sender] = true;
        emit Confirmation(msg.sender, transactionId);
        // attempt to execute the function.
        executeTransaction(transactionId);
    }

    /// @dev Allows an owner to revoke a confirmation for a transaction.
    /// @param transactionId Transaction ID.
    function revokeConfirmation(uint transactionId) public {
        require(isOwner[msg.sender]);
        require(transactions[transactionId].destination != address(0));
        require(confirmations[transactionId][msg.sender] == true); // should revoke already confirmed
        confirmations[transactionId][msg.sender] = false;
        emit Revoke(msg.sender, transactionId);
        executeTransaction(transactionId);
    }

    /// @dev Allows anyone to execute a confirmed transaction.
    /// @param transactionId Transaction ID.
    function executeTransaction(uint transactionId) public {
        require(transactions[transactionId].executed == false);
        if(isConfirmed(transactionId)) {
            Transaction storage tx = transactions[transactionId]; // using the "storage" keyword makes "t" a pointer to storage 
            tx.executed = true;
            
            (bool success, bytes memory returnedData) = tx.destination.call.value(tx.value)(tx.data);
            if(success) {
                emit Execution(transactionId);
            }
            else {
                emit ExecutionFailed(transactionId);
                tx.executed = false;
            }
        }
    }

		/*
		 * (Possible) Helper Functions
		 */
    /// @dev Returns the confirmation status of a transaction.
    /// @param transactionId Transaction ID.
    /// @return Confirmation status.
    function isConfirmed(uint transactionId) internal view returns (bool) {
        uint count = 0;
        // To do this we will loop over the owners array and count how many of the owners have confirmed the transaction. 
        // If the count reaches the required amount, we can stop counting (save gas) and just say the requirement has been reached.
        for (uint i = 0; i < owners.length; i++) {
            if (confirmations[transactionId][owners[i]]) {
                count += 1;
            }
            if (count == required) {
                return true;
            }
        }
    }

    /// @dev Adds a new transaction to the transaction mapping, if transaction does not exist yet.
    /// @param destination Transaction target address.
    /// @param value Transaction ether value.
    /// @param data Transaction data payload.
    /// @return Returns transaction ID.
    function addTransaction(address destination, uint value, bytes memory data) internal returns (uint transactionId) {
        transactionId = transactionCount;
        transactions[transactionId] = Transaction({
           destination: destination,
           value: value,
           data: data,
           executed: false
        });
        transactionCount += 1;
        emit Submission(transactionId);
        // The uint transactionId is returned for the submitTransaction function to hand over to the confirmTransaction function.
    }
}

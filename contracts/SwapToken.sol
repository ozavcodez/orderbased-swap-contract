// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SwapToken {
    // Create an order-based swap contract that allows users to deposit various kinds of tokens. These tokens can be purchased by others with another token specified by the depositors.
    // For example; Ada deposits 100 GUZ tokens; she wants in return, 20 W3B tokens for the 100 GUZ tokens.
    error ZeroAddressDetected();
    error ZeroValueNotAllowed();
    error TransferFailed();
    error NotApproved();
    error OrderExpired();
    error OrderAlreadyFufilled();
    error OrderNotExpired();

    uint256 public orderId;

    struct SwapOrder {
        address depositor;
        address tokenName;
        uint256 tokenAmount;
        address desiredToken;
        uint256 desiredTokenAmt;
        bool isCompleted;
        uint expiry;
    }
    mapping(uint => SwapOrder) public orders;
    // Event to track deposits
    event TokenDeposited(
        address indexed depositor,
        address indexed tokenName,
        uint256 tokenAmount,
        address desiredToken,
        uint256 desiredTokenAmt,
        uint256 orderId,
        uint256 expiry
    );

    // Event to track cancellations
    event OrderCancelled(address indexed depositor, uint256 orderId);

    function depositToken(
        address _tokenName,
        uint256 _tokenAmount,
        address _desiredToken,
        uint256 _desiredTokenAmt,
        uint256 _expiry
    ) external {
        if (msg.sender == address(0)) {
            revert ZeroAddressDetected();
        }

        if (_tokenAmount <= 0) {
            revert ZeroValueNotAllowed();
        }
        // Check if the user has approved the contract to spend their tokens
        uint256 allowance = IERC20(_tokenName).allowance(
            msg.sender,
            address(this)
        );
        if (allowance < _tokenAmount) {
            revert NotApproved(); // Custom error for approval check
        }

        bool success = IERC20(_tokenName).transferFrom(
            msg.sender,
            address(this),
            _tokenAmount
        );
        if (!success) {
            revert TransferFailed(); // In case transfer fails
        }
        orderId++;

        SwapOrder storage order = orders[orderId];
        order.depositor = msg.sender;
        order.desiredToken = _desiredToken;
        order.desiredTokenAmt = _desiredTokenAmt;
        order.tokenAmount = _tokenAmount;
        order.tokenName = _tokenName;
        order.isCompleted = false;
        order.expiry = _expiry;

        // Emit an event for the deposit
        emit TokenDeposited(
            msg.sender,
            _tokenName,
            _tokenAmount,
            _desiredToken,
            _desiredTokenAmt,
            orderId,
            _expiry
        );
    }

    function swapToken(uint256 _orderId) external {
        SwapOrder storage order = orders[_orderId];

        if (order.isCompleted) {
            revert OrderAlreadyFufilled();
        }

        if (block.timestamp > order.expiry) {
            revert OrderExpired();
        }

        bool success1 = IERC20(order.desiredToken).transferFrom(
            msg.sender,
            order.depositor,
            order.desiredTokenAmt
        );
        if (!success1) {
            revert TransferFailed();
        }
        bool success2 = IERC20(order.tokenName).transfer(
            msg.sender,
            order.tokenAmount
        );
        if (!success2) {
            revert TransferFailed();
        }

        // Mark the order as completed
        order.isCompleted = true;
    }

    function cancelOrder(uint _orderId) external {
        SwapOrder storage order = orders[_orderId];
        require(
            msg.sender == order.depositor,
            "only depositor can cancell this order"
        );

        if (block.timestamp <= order.expiry) {
            revert OrderNotExpired();
        }

        bool success = IERC20(order.tokenName).transfer(
            order.depositor,
            order.desiredTokenAmt
        );

        if (!success) {
            revert TransferFailed();
        }

        order.isCompleted = true;

        // Emit event for cancellation
        emit OrderCancelled(order.depositor, _orderId);
    }
}

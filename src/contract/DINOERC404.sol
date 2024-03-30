//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC404} from "../ERC404.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract DINOERC404 is Ownable, ERC404 {
  constructor(
    string memory name_,
    string memory symbol_,
    uint8 decimals_,
    address initialOwner_,
    uint256 maxMint_
    //address _recipient
  ) ERC404(name_, symbol_, decimals_) Ownable(initialOwner_) {
    MAX_MINT = maxMint_ * 10 ** decimals;
    
    //recipient = _recipient;
  }

  // Mapping to keep track of whether an address has minted
    mapping(address => bool) private hasMinted;
    mapping(address => bool) public whitelist;
    uint256 public MAX_MINT;
    address public VOYAGE = 0x0872ec4426103482a50f26Ffc32aCEfcec61b3c9;
    IERC1155 erc1151 = IERC1155(VOYAGE);
    // Address to receive the transferred funds
    address public recipient;
    uint256 public MAX_WHITELIST_SIZE = 800;
    uint256 public WHITELIST_COUNT = 0;

    // URI for the token metadata
    string private URI = "https://bafybeicflld7mcl6or5tuteeujpmkxs6wqsvkwpdfjem532dobvgac6swq.ipfs.w3s.link/";

    // Amount to be transferred (0.0018 ETH in this case)
    uint256 public transferAmount = 0.0018 ether;

    // Events for tracking whitelist changes
    event WhitelistAdded(address indexed account);
    event WhitelistRemoved(address indexed account);
    event Minted(address indexed account);

    function tokenURI(uint256 id_) public view override returns (string memory) {
    // Concatenate the base URI with the token ID using Strings.toString
    return string.concat(URI, Strings.toString(id_));
    }

    function setERC721TransferExempt(
      address account_,
      bool value_
    ) external onlyOwner {
      _setERC721TransferExempt(account_, value_);
    }

    // Function to add multiple addresses to the whitelist in one transaction
    // Takes an array of addresses to be whitelisted
    function addToWhitelist(address[] calldata addresses) external onlyOwner {
        require(WHITELIST_COUNT <= MAX_WHITELIST_SIZE, "Whitelist limit reached");
        for (uint256 i = 0; i < addresses.length; i++) {
            whitelist[addresses[i]] = true;
            WHITELIST_COUNT += 1;
            emit WhitelistAdded(addresses[i]);
        }
    }

    // Function to remove addresses from the whitelist
    // Takes an array of addresses to be removed
    function removeFromWhitelist(address[] calldata addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            if (whitelist[addresses[i]]) {
                whitelist[addresses[i]] = false;
                emit WhitelistRemoved(addresses[i]);
            }
        }
    }

    function createUserArray(uint256 size, address value) internal pure returns (address[] memory) {
        address[] memory newArray = new address[](size);
        for (uint256 i = 0; i < size; i++) {
            newArray[i] = value;
        }
        return newArray;
    }

    function createDynamicArray(uint256 size) internal pure returns (uint256[] memory) {
        uint256[] memory dynamicArray = new uint256[](size);
        for (uint256 i = 0; i < size; i++) {
            dynamicArray[i] = i + 1;
        }

        return dynamicArray;
    }

    // Check if user has at least one VOYAGE NFT
    function hasVoyageNft() public view returns (bool) {
        //uint256 supply = IERC1155.currentSupply();

        // Create the accounts array filled with the caller's address
        address[] memory accounts = createUserArray(5, msg.sender);

        // Create the ids array with values from 1 to supply
        uint256[] memory ids = createDynamicArray(5);

        uint256[] memory balances = erc1151.balanceOfBatch(accounts, ids);

        // Ensure valid input lengths
        if (balances.length != accounts.length || balances.length != ids.length) {
            revert("Invalid input lengths");
        }

        // Check for any non-zero balance
        for (uint256 i = 0; i < balances.length; i++) {
            if (balances[i] > 0) {
                return true; // At least one VOYAGE NFT found
            }
        }

        return false; // No VOYAGE NFTs found
    }

    function updateTransferAmount(uint256 _newAmount) public onlyOwner {
        transferAmount = _newAmount;
    }

    function mintERC20() external payable {
      require(totalSupply <= MAX_MINT, "Max mint limit reached");
      require(!hasMinted[msg.sender], "Already minted");
      if (whitelist[msg.sender]) {
        // Mint for free if whitelisted
        _mintERC20(msg.sender, 1 * 10 ** decimals);
      } else if (hasVoyageNft()) {
        // Existing logic for VOYAGE NFT holders with payment
        // Ensure the contract receives the exact amount
        require(msg.value == transferAmount, "Must send the exact amount (0.0018 ETH)");

        // Transfer funds to recipient
        (bool success,) = payable(recipient).call{value: transferAmount}("");

        // Check if transfer succeeded
        require(success, "Transfer failed");
        _mintERC20(msg.sender, 1 * 10 ** decimals);
      }
      hasMinted[msg.sender] = true;
      emit Minted(msg.sender);
    }

    function setURI(string memory newURI) public onlyOwner {
      require(bytes(newURI).length > 0, "URI cannot be empty");
      URI = newURI;
    }

    // Check if user is whitelisted
    function isWhitelisted(address account) public view returns (bool) {
      return whitelist[account];
    }
}

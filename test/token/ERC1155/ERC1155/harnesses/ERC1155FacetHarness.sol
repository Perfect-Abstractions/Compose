// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC1155Facet} from "../../../../../src/token/ERC1155/ERC1155Facet.sol";

/**
 * @title ERC1155FacetHarness
 * @notice Test harness for ERC1155Facet that adds initialization and minting for testing
 */
contract ERC1155FacetHarness is ERC1155Facet {
    /**
     * @notice Initialize the ERC1155 storage
     * @dev Only used for testing - production diamonds should initialize in constructor
     */
    function initialize(string memory _uri) external {
        ERC1155Storage storage s = getStorage();
        s.uri = _uri;
    }

    /**
     * @notice Set the base URI
     * @dev Only used for testing
     */
    function setBaseURI(string memory _baseURI) external {
        ERC1155Storage storage s = getStorage();
        s.baseURI = _baseURI;
    }

    /**
     * @notice Set a token-specific URI
     * @dev Only used for testing
     */
    function setTokenURI(uint256 _tokenId, string memory _tokenURI) external {
        ERC1155Storage storage s = getStorage();
        s.tokenURIs[_tokenId] = _tokenURI;
        string memory fullURI = bytes(_tokenURI).length > 0 ? string.concat(s.baseURI, _tokenURI) : s.uri;
        emit URI(fullURI, _tokenId);
    }

    /**
     * @notice Mint tokens to an address
     * @dev Only used for testing - exposes internal mint functionality
     */
    function mint(address _to, uint256 _id, uint256 _value) external {
        if (_to == address(0)) {
            revert ERC1155InvalidReceiver(address(0));
        }
        ERC1155Storage storage s = getStorage();
        s.balanceOf[_id][_to] += _value;
        emit TransferSingle(msg.sender, address(0), _to, _id, _value);
    }

    /**
     * @notice Mint multiple token types to an address
     * @dev Only used for testing - exposes internal mintBatch functionality
     */
    function mintBatch(address _to, uint256[] memory _ids, uint256[] memory _values) external {
        if (_to == address(0)) {
            revert ERC1155InvalidReceiver(address(0));
        }
        if (_ids.length != _values.length) {
            revert ERC1155InvalidArrayLength(_ids.length, _values.length);
        }
        ERC1155Storage storage s = getStorage();
        for (uint256 i = 0; i < _ids.length; i++) {
            s.balanceOf[_ids[i]][_to] += _values[i];
        }
        emit TransferBatch(msg.sender, address(0), _to, _ids, _values);
    }

    /**
     * @notice Burn tokens from an address
     * @dev Only used for testing - exposes internal burn functionality
     */
    function burn(address _from, uint256 _id, uint256 _value) external {
        if (_from == address(0)) {
            revert ERC1155InvalidSender(address(0));
        }
        ERC1155Storage storage s = getStorage();
        uint256 fromBalance = s.balanceOf[_id][_from];
        if (fromBalance < _value) {
            revert ERC1155InsufficientBalance(_from, fromBalance, _value, _id);
        }
        unchecked {
            s.balanceOf[_id][_from] = fromBalance - _value;
        }
        emit TransferSingle(msg.sender, _from, address(0), _id, _value);
    }

    /**
     * @notice Burn multiple token types from an address
     * @dev Only used for testing - exposes internal burnBatch functionality
     */
    function burnBatch(address _from, uint256[] memory _ids, uint256[] memory _values) external {
        if (_from == address(0)) {
            revert ERC1155InvalidSender(address(0));
        }
        if (_ids.length != _values.length) {
            revert ERC1155InvalidArrayLength(_ids.length, _values.length);
        }
        ERC1155Storage storage s = getStorage();
        for (uint256 i = 0; i < _ids.length; i++) {
            uint256 id = _ids[i];
            uint256 value = _values[i];
            uint256 fromBalance = s.balanceOf[id][_from];
            if (fromBalance < value) {
                revert ERC1155InsufficientBalance(_from, fromBalance, value, id);
            }
            unchecked {
                s.balanceOf[id][_from] = fromBalance - value;
            }
        }
        emit TransferBatch(msg.sender, _from, address(0), _ids, _values);
    }
}

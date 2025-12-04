// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import "../../../../../src/token/ERC1155/ERC1155Mod.sol" as ERC1155;

/**
 * @title ERC1155Harness
 * @notice Test harness that exposes LibERC1155's internal functions as external
 * @dev Required for testing since LibERC1155 only has internal functions
 */
contract ERC1155Harness {
    /**
     * @notice Initialize the ERC1155 storage
     * @dev Only used for testing
     */
    function initialize(string memory _uri) external {
        ERC1155.ERC1155Storage storage s = ERC1155.getStorage();
        s.uri = _uri;
    }

    /**
     * @notice Set the base URI
     */
    function setBaseURI(string memory _baseURI) external {
        ERC1155.setBaseURI(_baseURI);
    }

    /**
     * @notice Set a token-specific URI
     */
    function setTokenURI(uint256 _tokenId, string memory _tokenURI) external {
        ERC1155.setTokenURI(_tokenId, _tokenURI);
    }

    /**
     * @notice Exposes ERC1155.mint as an external function
     */
    function mint(address _to, uint256 _id, uint256 _value) external {
        ERC1155.mint(_to, _id, _value, new bytes(0));
    }

    /**
     * @notice Exposes ERC1155.mintBatch as an external function
     */
    function mintBatch(address _to, uint256[] memory _ids, uint256[] memory _values) external {
        ERC1155.mintBatch(_to, _ids, _values, new bytes(0));
    }

    /**
     * @notice Exposes ERC1155.burn as an external function
     */
    function burn(address _from, uint256 _id, uint256 _value) external {
        ERC1155.burn(_from, _id, _value);
    }

    /**
     * @notice Exposes ERC1155.burnBatch as an external function
     */
    function burnBatch(address _from, uint256[] memory _ids, uint256[] memory _values) external {
        ERC1155.burnBatch(_from, _ids, _values);
    }

    /**
     * @notice Exposes ERC1155.safeTransferFrom as an external function
     */
    function safeTransferFrom(address _from, address _to, uint256 _id, uint256 _value) external {
        ERC1155.safeTransferFrom(_from, _to, _id, _value, msg.sender);
    }

    /**
     * @notice Exposes ERC1155.safeBatchTransferFrom as an external function
     */
    function safeBatchTransferFrom(address _from, address _to, uint256[] memory _ids, uint256[] memory _values)
        external
    {
        ERC1155.safeBatchTransferFrom(_from, _to, _ids, _values, msg.sender);
    }

    /**
     * @notice Get the URI for a token type
     */
    function uri(uint256 _id) external view returns (string memory) {
        ERC1155.ERC1155Storage storage s = ERC1155.getStorage();
        string memory tokenURI = s.tokenURIs[_id];
        return bytes(tokenURI).length > 0 ? string.concat(s.baseURI, tokenURI) : s.uri;
    }

    /**
     * @notice Get the balance of an account for a token type
     */
    function balanceOf(address _account, uint256 _id) external view returns (uint256) {
        return ERC1155.getStorage().balanceOf[_id][_account];
    }

    /**
     * @notice Get balances for multiple account/token pairs
     */
    function balanceOfBatch(address[] memory _accounts, uint256[] memory _ids)
        external
        view
        returns (uint256[] memory)
    {
        require(_accounts.length == _ids.length, "Length mismatch");
        uint256[] memory balances = new uint256[](_accounts.length);
        ERC1155.ERC1155Storage storage s = ERC1155.getStorage();
        for (uint256 i = 0; i < _accounts.length; i++) {
            balances[i] = s.balanceOf[_ids[i]][_accounts[i]];
        }
        return balances;
    }

    /**
     * @notice Check if an operator is approved for all tokens of an account
     */
    function isApprovedForAll(address _account, address _operator) external view returns (bool) {
        return ERC1155.getStorage().isApprovedForAll[_account][_operator];
    }

    /**
     * @notice Set approval for an operator
     */
    function setApprovalForAll(address _operator, bool _approved) external {
        ERC1155.ERC1155Storage storage s = ERC1155.getStorage();
        s.isApprovedForAll[msg.sender][_operator] = _approved;
    }
}

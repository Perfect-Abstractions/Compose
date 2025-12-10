// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract ERC4626Facet {
    error ERC4626InvalidAmount();
    error ERC4626InvalidAddress();
    error ERC4626TransferFailed();
    error ERC4626InsufficientShares();
    error ERC4626InsufficientAssets();

    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(
        address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

    bytes32 constant ERC20_STORAGE_POSITION = keccak256("compose.erc20");
    bytes32 constant STORAGE_POSITION = keccak256("compose.erc4626");

    uint256 constant VIRTUAL_ASSET = 1;
    uint256 constant VIRTUAL_SHARE = 1;

    struct ERC20Storage {
        mapping(address => uint256) balanceOf;
        uint256 totalSupply;
        mapping(address => mapping(address => uint256)) allowances;
        uint8 decimals;
        string name;
        string symbol;
    }

    struct ERC4626Storage {
        IERC20 asset;
    }

    function getERC20Storage() internal pure returns (ERC20Storage storage s) {
        bytes32 position = ERC20_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    function getStorage() internal pure returns (ERC4626Storage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    function asset() external view returns (address) {
        ERC4626Storage storage s = getStorage();
        return address(s.asset);
    }

    function totalAssets() external view returns (uint256) {
        ERC4626Storage storage s = getStorage();
        return s.asset.balanceOf(address(this)) + VIRTUAL_ASSET;
    }

    function muldiv(uint256 a, uint256 b, uint256 denominator) internal view returns (uint256 result) {
        require(denominator > 0);

        uint256 prod0;
        uint256 prod1;
        assembly {
            let mm := mulmod(a, b, not(0))
            prod0 := mul(a, b)
            prod1 := sub(sub(mm, prod0), lt(mm, prod0))
        }

        if (prod1 == 0) {
            assembly {
                result := div(prod0, denominator)
            }
            return result;
        }

        require(prod1 < denominator);

        uint256 remainder;
        assembly {
            remainder := mulmod(a, b, denominator)
        }
        assembly {
            prod1 := sub(prod1, gt(remainder, prod0))
            prod0 := sub(prod0, remainder)
        }

        uint256 twos = (~denominator + 1) & denominator;
        assembly {
            denominator := div(denominator, twos)
        }

        assembly {
            prod0 := div(prod0, twos)
        }

        assembly {
            twos := add(div(sub(0, twos), twos), 1)
        }
        prod0 |= prod1 * twos;

        uint256 inv = (3 * denominator) ^ 2;
        inv *= 2 - denominator * inv;
        inv *= 2 - denominator * inv;
        inv *= 2 - denominator * inv;
        inv *= 2 - denominator * inv;
        inv *= 2 - denominator * inv;
        inv *= 2 - denominator * inv;

        result = prod0 * inv;
        return result;
    }

    function mulDivRoundingUp(uint256 a, uint256 b, uint256 denominator) internal view returns (uint256 result) {
        result = muldiv(a, b, denominator);
        if (mulmod(a, b, denominator) > 0) {
            require(result < type(uint256).max);
            result++;
        }
    }

    function totalShares() external view returns (uint256) {
        ERC20Storage storage erc20s = getERC20Storage();
        return erc20s.totalSupply + VIRTUAL_SHARE;
    }

    function convertToShares(uint256 assets) external view returns (uint256) {
        ERC20Storage storage erc20s = getERC20Storage();
        uint256 totalShares_ = erc20s.totalSupply + VIRTUAL_SHARE;

        ERC4626Storage storage s = getStorage();
        uint256 totalAssets_ = s.asset.balanceOf(address(this)) + VIRTUAL_ASSET;

        return muldiv(totalShares_, assets, totalAssets_);
    }

    function convertToAssets(uint256 shares) external view returns (uint256) {
        ERC20Storage storage erc20s = getERC20Storage();
        uint256 totalShares_ = erc20s.totalSupply + VIRTUAL_SHARE;
        ERC4626Storage storage s = getStorage();
        uint256 totalAssets_ = s.asset.balanceOf(address(this)) + VIRTUAL_ASSET;

        return muldiv(totalAssets_, shares, totalShares_);
    }

    function maxDeposit() external pure returns (uint256) {
        return type(uint256).max;
    }

    function previewDeposit(uint256 assets) external view returns (uint256) {
        ERC20Storage storage erc20s = getERC20Storage();
        uint256 totalShares_ = erc20s.totalSupply + VIRTUAL_SHARE;
        ERC4626Storage storage s = getStorage();
        uint256 totalAssets_ = s.asset.balanceOf(address(this)) + VIRTUAL_ASSET;

        return muldiv(totalShares_, assets, totalAssets_);
    }

    function deposit(uint256 assets, address receiver) external returns (uint256) {
        if (receiver == address(0)) {
            revert ERC4626InvalidAddress();
        }

        if (assets > type(uint256).max) {
            revert ERC4626InvalidAmount();
        }

        ERC20Storage storage erc20s = getERC20Storage();
        uint256 totalShares_ = erc20s.totalSupply + VIRTUAL_SHARE;
        ERC4626Storage storage s = getStorage();
        uint256 totalAssets_ = s.asset.balanceOf(address(this)) + VIRTUAL_ASSET;

        uint256 shares;

        shares = muldiv(totalShares_, assets, totalAssets_);

        if (shares == 0) {
            revert ERC4626InsufficientShares();
        }

        bool success = s.asset.transferFrom(msg.sender, address(this), assets);
        if (!success) {
            revert ERC4626TransferFailed();
        }

        erc20s.totalSupply += shares;
        erc20s.balanceOf[receiver] += shares;

        emit Deposit(msg.sender, receiver, assets, shares);
        return shares;
    }

    function maxMint() external pure returns (uint256) {
        return type(uint256).max;
    }

    function previewMint(uint256 shares) external view returns (uint256) {
        ERC20Storage storage erc20s = getERC20Storage();
        uint256 totalShares_ = erc20s.totalSupply + VIRTUAL_SHARE;
        ERC4626Storage storage s = getStorage();
        uint256 totalAssets_ = s.asset.balanceOf(address(this)) + VIRTUAL_ASSET;
        return mulDivRoundingUp(totalAssets_, shares, totalShares_);
    }

    function mint(uint256 shares, address receiver) external returns (uint256) {
        if (receiver == address(0)) {
            revert ERC4626InvalidAddress();
        }

        if (shares > type(uint256).max) {
            revert ERC4626InvalidAmount();
        }

        ERC20Storage storage erc20s = getERC20Storage();
        uint256 totalShares_ = erc20s.totalSupply + VIRTUAL_SHARE;
        ERC4626Storage storage s = getStorage();
        uint256 totalAssets_ = s.asset.balanceOf(address(this)) + VIRTUAL_ASSET;

        uint256 assets;

        assets = mulDivRoundingUp(totalAssets_, shares, totalShares_);

        if (assets == 0) {
            revert ERC4626InsufficientAssets();
        }

        bool success = s.asset.transferFrom(msg.sender, address(this), assets);
        if (!success) {
            revert ERC4626TransferFailed();
        }

        erc20s.totalSupply += shares;
        erc20s.balanceOf[receiver] += shares;

        emit Deposit(msg.sender, receiver, assets, shares);
        return assets;
    }

    function maxWithdraw(address owner) external view returns (uint256) {
        ERC20Storage storage erc20s = getERC20Storage();
        uint256 balance = erc20s.balanceOf[owner];
        ERC4626Storage storage s = getStorage();
        uint256 totalAssets_ = s.asset.balanceOf(address(this)) + VIRTUAL_ASSET;
        uint256 totalShares_ = erc20s.totalSupply + VIRTUAL_SHARE;
        return muldiv(totalAssets_, balance, totalShares_);
    }

    function previewWithdraw(uint256 assets) external view returns (uint256) {
        ERC20Storage storage erc20s = getERC20Storage();
        uint256 totalShares_ = erc20s.totalSupply + VIRTUAL_SHARE;
        ERC4626Storage storage s = getStorage();
        uint256 totalAssets_ = s.asset.balanceOf(address(this)) + VIRTUAL_ASSET;

        return mulDivRoundingUp(totalShares_, assets, totalAssets_);
    }

    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256) {
        if (receiver == address(0) || owner == address(0)) {
            revert ERC4626InvalidAddress();
        }

        ERC20Storage storage erc20s = getERC20Storage();
        uint256 balance = erc20s.balanceOf[owner];
        ERC4626Storage storage s = getStorage();
        uint256 totalAssets_ = s.asset.balanceOf(address(this)) + VIRTUAL_ASSET;
        uint256 totalShares_ = erc20s.totalSupply + VIRTUAL_SHARE;

        uint256 maxWithdrawVal = muldiv(totalAssets_, balance, totalShares_);
        if (assets > maxWithdrawVal) {
            revert ERC4626InvalidAmount();
        }

        uint256 shares;

        shares = mulDivRoundingUp(totalShares_, assets, totalAssets_);

        if (shares == 0) {
            revert ERC4626InsufficientShares();
        }

        bool success = s.asset.transfer(receiver, assets);
        if (!success) {
            revert ERC4626TransferFailed();
        }

        if (msg.sender != owner) {
            uint256 allowed = erc20s.allowances[owner][msg.sender];
            if (allowed < shares) {
                revert ERC4626InvalidAmount();
            }
            erc20s.allowances[owner][msg.sender] = allowed - shares;
        }
        erc20s.balanceOf[owner] -= shares;
        erc20s.totalSupply -= shares;

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        return shares;
    }

    function maxRedeem(address owner) external view returns (uint256) {
        ERC20Storage storage erc20s = getERC20Storage();
        return erc20s.balanceOf[owner];
    }

    function previewRedeem(uint256 shares) external view returns (uint256) {
        ERC20Storage storage erc20s = getERC20Storage();
        uint256 totalShares_ = erc20s.totalSupply + VIRTUAL_SHARE;
        ERC4626Storage storage s = getStorage();
        uint256 totalAssets_ = s.asset.balanceOf(address(this)) + VIRTUAL_ASSET;

        return muldiv(totalAssets_, shares, totalShares_);
    }

    function redeem(uint256 shares, address receiver, address owner) external returns (uint256) {
        if (receiver == address(0) || owner == address(0)) {
            revert ERC4626InvalidAddress();
        }

        ERC20Storage storage erc20s = getERC20Storage();

        if (shares > erc20s.balanceOf[owner]) {
            revert ERC4626InvalidAmount();
        }

        ERC4626Storage storage s = getStorage();
        uint256 totalShares_ = erc20s.totalSupply + VIRTUAL_SHARE;
        uint256 totalAssets_ = s.asset.balanceOf(address(this)) + VIRTUAL_ASSET;
        uint256 assets;

        assets = muldiv(totalAssets_, shares, totalShares_);

        if (assets == 0) {
            revert ERC4626InsufficientAssets();
        }

        bool success = s.asset.transfer(receiver, assets);
        if (!success) {
            revert ERC4626TransferFailed();
        }

        if (msg.sender != owner) {
            uint256 allowed = erc20s.allowances[owner][msg.sender];
            if (allowed < shares) {
                revert ERC4626InvalidAmount();
            }
            erc20s.allowances[owner][msg.sender] = allowed - shares;
        }
        erc20s.totalSupply -= shares;
        erc20s.balanceOf[owner] -= shares;

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        return assets;
    }
}

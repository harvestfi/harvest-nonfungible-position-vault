//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// External Packages
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

// Libraries
import {AppStorage, LibAppStorage} from "./LibAppStorage.sol";
import {LibPositionManager} from "./LibPositionManager.sol";
import {LibEvents} from "./LibEvents.sol";

// Helpers
import {Modifiers} from "../core/Modifiers.sol";

library LibTokenizedVault {
    using MathUpgradeable for uint256;

    function __ERC20_init_unchained(string memory _name, string memory _symbol) internal {
        AppStorage storage s = LibAppStorage.systemStorage();
        s.name = _name;
        s.symbol = _symbol;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.systemStorage();
        return s.totalSupply;
    }

    /**
     * @dev See {IERC4626-totalAssets}.
     */
    function totalAssets() internal view returns (uint256 totalLiquidity) {
        AppStorage storage s = LibAppStorage.systemStorage();
        return s.liquidity;
    }

    //HACK: Check for implementations here
    function decimalsOffset() internal view returns (uint8) {
        return 0;
    }

    /**
     * @dev Internal conversion function (from assets to shares) with support for rounding direction.
     */
    function convertToShares(uint256 assets, MathUpgradeable.Rounding rounding) internal view returns (uint256) {
        return assets.mulDiv(totalSupply() + 10 ** decimalsOffset(), totalAssets() + 1, rounding);
    }

    /**
     * @dev Internal conversion function (from shares to assets) with support for rounding direction.
     */
    function convertToAssets(uint256 shares, MathUpgradeable.Rounding rounding) internal view returns (uint256) {
        return shares.mulDiv(totalAssets() + 1, totalSupply() + 10 ** decimalsOffset(), rounding);
    }

    /**
     * @dev Deposit/mint common workflow.
     */
    function deposit(address caller, address receiver, uint256 assets, uint256 shares) internal {
        AppStorage storage s = LibAppStorage.systemStorage();
        // If _asset is ERC777, `transferFrom` can trigger a reentrancy BEFORE the transfer happens through the
        // `tokensToSend` hook. On the other hand, the `tokenReceived` hook, that is triggered after the transfer,
        // calls the vault, which is assumed not malicious.
        //
        // Conclusion: we need to do the transfer before we mint so that any reentrancy would happen before the
        // assets are transferred and before the shares are minted, which is a valid state.
        // slither-disable-next-line reentrancy-no-eth
        SafeERC20Upgradeable.safeTransferFrom(IERC20Upgradeable(s.token0), caller, address(this), assets);
        SafeERC20Upgradeable.safeTransferFrom(IERC20Upgradeable(s.token1), caller, address(this), assets);

        /// TODO
        /*
        // zap funds if desired
        (uint256 zapActualAmountOut0, uint256 zapActualAmountOut1) = (0, 0);
        if (_zapFunds) {
            (zapActualAmountOut0, zapActualAmountOut1) = _zap(_zapAmount0OutMin, _zapAmount1OutMin, _zapSqrtPriceLimitX96);
        }

        // the assumes that the deposits are already in
        // they were transferred in by the deposit method, and potentially zap-swapped
        uint256 previousUnderlyingBalanceWithInvestment = IUniVaultV1(address(this)).underlyingBalanceWithInvestment();
        uint256 _amount0 = token0().balanceOf(address(this));
        uint256 _amount1 = token1().balanceOf(address(this));
        // approvals for the liquidity increase
        token0().safeApprove(_NFT_POSITION_MANAGER, 0);
        token0().safeApprove(_NFT_POSITION_MANAGER, _amount0);
        token1().safeApprove(_NFT_POSITION_MANAGER, 0);
        token1().safeApprove(_NFT_POSITION_MANAGER, _amount1);
        // increase the liquidity
        (uint128 _liquidity,,) = INonfungiblePositionManager(_NFT_POSITION_MANAGER).increaseLiquidity(
            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: getStorage().posId(),
                amount0Desired: _amount0,
                amount1Desired: _amount1,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            })
        );
        emit Deposit(_to, _amount0, _amount1);
        // mint shares of the vault to the recipient
        uint256 toMint = IERC20Upgradeable(address(this)).totalSupply() == 0
            ? uint256(_liquidity)
            : (uint256(_liquidity)).mul(IERC20Upgradeable(address(this)).totalSupply()).div(previousUnderlyingBalanceWithInvestment);
        _mint(_to, toMint);
        _transferLeftOverTo(msg.sender);
        ///

        mint(receiver, shares);

        emit LibEvents.Deposit(caller, receiver, assets, shares);
        */
    }

    /**
     * @dev Withdraw/redeem common workflow.
     */
    function withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares) internal {
        AppStorage storage s = LibAppStorage.systemStorage();
        if (caller != owner) {
            spendAllowance(owner, caller, shares);
        }

        // If _asset is ERC777, `transfer` can trigger a reentrancy AFTER the transfer happens through the
        // `tokensReceived` hook. On the other hand, the `tokensToSend` hook, that is triggered before the transfer,
        // calls the vault, which is assumed not malicious.
        //
        // Conclusion: we need to do the transfer after the burn so that any reentrancy would happen after the
        // shares are burned and after the assets are transferred, which is a valid state.
        burn(owner, shares);
        SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(s.underlyingToken), receiver, assets);

        /// TODO
        /*
        require(_token0 || _token1, "At least one side must be wanted");
        // calculates the liquidity before burning any shares
        uint128 liquidityShare = uint128(
            (IUniVaultV1(address(this)).underlyingBalanceWithInvestment()).mul(_numberOfShares).div(
                IERC20Upgradeable(address(this)).totalSupply()
            )
        );
        // burn the respective shares
        // guards the balance via safe math in burn
        _burn(msg.sender, _numberOfShares);
        // withdraw liquidity from the NFT
        (uint256 _receivedToken0, uint256 _receivedToken1) = INonfungiblePositionManager(_NFT_POSITION_MANAGER).decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: getStorage().posId(),
                liquidity: liquidityShare,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            })
        );
        // collect the amount fetched above
        INonfungiblePositionManager(_NFT_POSITION_MANAGER).collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: getStorage().posId(),
                recipient: address(this),
                amount0Max: uint128(_receivedToken0), // collect all token0 accounted for the liquidity
                amount1Max: uint128(_receivedToken1) // collect all token1 accounted for the liquidity
            })
        );

        (uint256 zapActualAmountOut0, uint256 zapActualAmountOut1) = (0, 0);

        // make swaps as desired
        if (!_token0) {
            uint256 balance0 = token0().balanceOf(address(this));
            if (balance0 > 0) {
                (zapActualAmountOut0, zapActualAmountOut1) = _swap(balance0, 0, 0, _amount1OutMin, _sqrtPriceLimitX96);
            }
        }
        if (!_token1) {
            uint256 balance1 = token1().balanceOf(address(this));
            if (balance1 > 0) {
                (zapActualAmountOut0, zapActualAmountOut1) = _swap(0, balance1, _amount0OutMin, 0, _sqrtPriceLimitX96);
            }
        }

        emit Withdraw(msg.sender, _receivedToken0, _receivedToken1);
        // transfer everything we have in the contract to msg.sender
        _transferLeftOverTo(msg.sender);
        ///

        emit LibEvents.Withdraw(caller, receiver, owner, assets, shares);
        */
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function transfer(address from, address to, uint256 amount) internal {
        AppStorage storage s = LibAppStorage.systemStorage();
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = s.balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            s.balances[from] = fromBalance - amount;
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            s.balances[to] += amount;
        }

        emit LibEvents.Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    /**
     * @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function mint(address account, uint256 amount) internal {
        AppStorage storage s = LibAppStorage.systemStorage();
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        s.totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            s.balances[account] += amount;
        }
        emit LibEvents.Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function burn(address account, uint256 amount) internal {
        AppStorage storage s = LibAppStorage.systemStorage();
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = s.balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            s.balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            s.totalSupply -= amount;
        }

        emit LibEvents.Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function approve(address owner, address spender, uint256 amount) internal {
        AppStorage storage s = LibAppStorage.systemStorage();
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        s.allowances[owner][spender] = amount;
        emit LibEvents.Approval(owner, spender, amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function spendAllowance(address owner, address spender, uint256 amount) internal {
        AppStorage storage s = LibAppStorage.systemStorage();
        uint256 currentAllowance = s.allowances[owner][spender];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(address from, address to, uint256 amount) internal {}
}

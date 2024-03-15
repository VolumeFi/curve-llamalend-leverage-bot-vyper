#pragma version 0.3.10
#pragma optimize gas
#pragma evm-version shanghai
"""
@title CryptoFromPool
@notice Price oracle for pools which contain cryptos and crvUSD. This is NOT suitable for minted crvUSD - only for lent out
@author Volume Finance
"""
interface Pool:
    def price_oracle(i: uint256 = 0) -> uint256: view  # Universal method!


MAX_SIZE: constant(uint256) = 8
POOLS: public(immutable(Pool[MAX_SIZE]))
BORROWED_IX: public(immutable(uint256[MAX_SIZE]))
COLLATERAL_IX: public(immutable(uint256[MAX_SIZE]))
N_COINS: public(immutable(uint256[MAX_SIZE]))
NO_ARGUMENT: public(immutable(bool[MAX_SIZE]))
POOL_COUNT: public(immutable(uint256))

@external
def __init__(
        pools: Pool[MAX_SIZE],
        N: uint256[MAX_SIZE],
        borrowed_ixs: uint256[MAX_SIZE],
        collateral_ixs: uint256[MAX_SIZE]
    ):
    POOLS = pools
    pool_count: uint256 = 0
    no_arguments: bool[MAX_SIZE] = empty(bool[MAX_SIZE])
    for i in range(MAX_SIZE):
        if pools[i] == empty(Pool):
            assert i != 0, "Wrong pool counts"
            pool_count = i
            break

        assert borrowed_ixs[i] != collateral_ixs[i]
        assert borrowed_ixs[i] < N[i]
        assert collateral_ixs[i] < N[i]

        if N[i] == 2:
            success: bool = False
            res: Bytes[32] = empty(Bytes[32])
            success, res = raw_call(
                pools[i].address,
                _abi_encode(empty(uint256), method_id=method_id("price_oracle(uint256)")),
                max_outsize=32, is_static_call=True, revert_on_failure=False)
            if not success:
                no_arguments[i] = True

    NO_ARGUMENT = no_arguments
    N_COINS = N
    BORROWED_IX = borrowed_ixs
    COLLATERAL_IX = collateral_ixs
    if pool_count == 0:
        pool_count = MAX_SIZE
    POOL_COUNT = pool_count

@internal
@view
def _raw_price() -> uint256:
    _price: uint256 = 10**18
    for i in range(MAX_SIZE):
        if i >= POOL_COUNT:
            break
        p_borrowed: uint256 = 10**18
        p_collateral: uint256 = 10**18

        if NO_ARGUMENT[i]:
            p: uint256 = POOLS[i].price_oracle()
            if COLLATERAL_IX[i] > 0:
                p_collateral = p
            else:
                p_borrowed = p

        else:
            if BORROWED_IX[i] > 0:
                p_borrowed = POOLS[i].price_oracle(unsafe_sub(BORROWED_IX[i], 1))
            if COLLATERAL_IX[i] > 0:
                p_collateral = POOLS[i].price_oracle(unsafe_sub(COLLATERAL_IX[i], 1))
        _price = _price * p_collateral / p_borrowed
    return _price


@external
@view
def price() -> uint256:
    return self._raw_price()


@external
def price_w() -> uint256:
    return self._raw_price()
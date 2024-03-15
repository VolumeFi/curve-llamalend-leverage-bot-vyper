#pragma version 0.3.10
#pragma optimize gas
#pragma evm-version shanghai
"""
@title Curve LLAMALEND Bot
@license Apache 2.0
@author Volume.finance
"""

interface Controller:
    def create_loan_extended(collateral: uint256, debt: uint256, N: uint256, callbacker: address, callback_args: DynArray[uint256,5]): payable
    def borrow_more_extended(collateral: uint256, debt: uint256, callbacker: address, callback_args: DynArray[uint256,5]): nonpayable
    def repay_extended(callbacker: address, callback_args: DynArray[uint256,5]): nonpayable
    def user_state(user: address) -> uint256[4]: view
    def health(user: address, full: bool) -> int256: view

interface WrappedEth:
    def withdraw(amount: uint256): nonpayable

interface ERC20:
    def balanceOf(_owner: address) -> uint256: view
    def approve(_spender: address, _value: uint256) -> bool: nonpayable
    def transfer(_to: address, _value: uint256) -> bool: nonpayable

FACTORY: immutable(address)
CONTROLLER: immutable(address)
COLLATERAL: immutable(address)
WETH: immutable(address)
OWNER: immutable(address)
STABLECOIN: immutable(address)

@external
@payable
def __init__(controller: address, weth: address, owner: address, collateral: address, stablecoin: address):
    FACTORY = msg.sender
    CONTROLLER = controller
    COLLATERAL = collateral
    WETH = weth
    OWNER = owner
    STABLECOIN = stablecoin

@external
def create_loan_extended(collateral_amount: uint256, debt: uint256, N: uint256, callbacker: address, callback_args: DynArray[uint256,5]):
    assert msg.sender == FACTORY, "not factory"
    assert ERC20(COLLATERAL).approve(CONTROLLER, collateral_amount, default_return_value=True), "Failed approve"
    Controller(CONTROLLER).create_loan_extended(collateral_amount, debt, N, callbacker, callback_args)

@external
def borrow_more_extended(collateral_amount: uint256, debt: uint256, callbacker: address, callback_args: DynArray[uint256, 5]):
    assert msg.sender == FACTORY, "not factory"
    assert ERC20(COLLATERAL).approve(CONTROLLER, collateral_amount, default_return_value=True), "Failed approve"
    Controller(CONTROLLER).borrow_more_extended(collateral_amount, debt, callbacker, callback_args)

@external
def repay_extended(callbacker: address, callback_args: DynArray[uint256,5]) -> uint256:
    assert msg.sender == FACTORY, "Unauthorized"
    bal: uint256 = ERC20(STABLECOIN).balanceOf(self)
    Controller(CONTROLLER).repay_extended(callbacker, callback_args)
    bal = unsafe_sub(ERC20(STABLECOIN).balanceOf(self), bal)
    assert bal > 0, "repay fail"
    assert ERC20(STABLECOIN).transfer(OWNER, bal, default_return_value=True), "Tr fail"
    return bal

@external
@view
def state() -> uint256[4]:
    return Controller(CONTROLLER).user_state(self)

@external
@view
def health() -> int256:
    return Controller(CONTROLLER).health(self, True)

@external
@payable
def __default__():
    pass

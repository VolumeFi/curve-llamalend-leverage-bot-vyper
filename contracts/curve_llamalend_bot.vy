#pragma version 0.3.10
#pragma optimize gas
#pragma evm-version shanghai
"""
@title Curve LLAMALEND Bot
@license Apache 2.0
@author Volume.finance
"""

interface Controller:
    def create_loan_extended(collateral: uint256, debt: uint256, N: uint256, callbacker: address, callback_args: DynArray[uint256,5], callback_bytes: Bytes[10**4]=b""): payable
    def borrow_more_extended(collateral: uint256, debt: uint256, callbacker: address, callback_args: DynArray[uint256,5], callback_bytes: Bytes[10**4]=b""): nonpayable
    def repay_extended(callbacker: address, callback_args: DynArray[uint256,5], callback_bytes: Bytes[10**4]=b""): nonpayable
    def user_state(user: address) -> uint256[4]: view
    def health(user: address, full: bool) -> int256: view

interface WrappedEth:
    def withdraw(amount: uint256): nonpayable

interface ERC20:
    def balanceOf(_owner: address) -> uint256: view
    def approve(_spender: address, _value: uint256) -> bool: nonpayable
    def transfer(_to: address, _value: uint256) -> bool: nonpayable

FACTORY: immutable(address)
CONTROLLER: public(immutable(address))
COLLATERAL: immutable(address)
WETH: immutable(address)
OWNER: immutable(address)
STABLECOIN: immutable(address)
callback_bytes: public(Bytes[10**4])
is_new_market: public(bool)

@external
@payable
def __init__(controller: address, weth: address, owner: address, collateral: address, stablecoin: address, is_new_market: bool):
    FACTORY = msg.sender
    CONTROLLER = controller
    COLLATERAL = collateral
    WETH = weth
    OWNER = owner
    STABLECOIN = stablecoin
    self.is_new_market = is_new_market

@internal
def _factory_check():
    assert msg.sender == FACTORY, "not factory"

@internal
def _safe_approve(_token: address, _to: address, _value: uint256):
    assert ERC20(_token).approve(_to, _value, default_return_value=True), "Failed approve"

@internal
def _safe_transfer(_token: address, _to: address, _value: uint256):
    assert ERC20(_token).transfer(_to, _value, default_return_value=True), "Failed transfer"

@external
def create_loan_extended(collateral_amount: uint256, debt: uint256, N: uint256, callbacker: address, callback_args: DynArray[uint256,5], callback_bytes: Bytes[10**4]):
    self._factory_check()
    self._safe_approve(COLLATERAL, CONTROLLER, collateral_amount)
    if self.is_new_market:
        Controller(CONTROLLER).create_loan_extended(collateral_amount, debt, N, callbacker, callback_args, callback_bytes)
    else:
        self.callback_bytes = callback_bytes
        Controller(CONTROLLER).create_loan_extended(collateral_amount, debt, N, callbacker, callback_args)
        self.callback_bytes = b""

@external
def borrow_more_extended(collateral_amount: uint256, debt: uint256, callbacker: address, callback_args: DynArray[uint256, 5], callback_bytes: Bytes[10**4]):
    self._factory_check()
    self._safe_approve(COLLATERAL, CONTROLLER, collateral_amount)
    if self.is_new_market:
        Controller(CONTROLLER).borrow_more_extended(collateral_amount, debt, callbacker, callback_args, callback_bytes)
    else:
        self.callback_bytes = callback_bytes
        Controller(CONTROLLER).borrow_more_extended(collateral_amount, debt, callbacker, callback_args)
        self.callback_bytes = b""

@external
def repay_extended(callbacker: address, callback_args: DynArray[uint256,5], callback_bytes: Bytes[10**4]) -> uint256:
    self._factory_check()
    bal: uint256 = ERC20(STABLECOIN).balanceOf(self)
    if self.is_new_market:
        Controller(CONTROLLER).repay_extended(callbacker, callback_args, callback_bytes)
    else:
        self.callback_bytes = callback_bytes
        Controller(CONTROLLER).repay_extended(callbacker, callback_args)
        self.callback_bytes = b""
    bal = unsafe_sub(ERC20(STABLECOIN).balanceOf(self), bal)
    if bal > 0:
        self._safe_transfer(STABLECOIN, OWNER, bal)
    return bal

@external
@nonreentrant('lock')
def emergency_withdraw(token: address, amount: uint256):
    if token == empty(address):
        send(OWNER, amount)
    else:
        self._safe_transfer(token, OWNER, amount)

@external
def set_new_market(is_new_market: bool):
    self._factory_check()
    self.is_new_market = is_new_market

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

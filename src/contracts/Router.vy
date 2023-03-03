# @version 0.3.8

struct DepositWithdrawalParams:
    coinPositionInCPU: uint256
    _amount: uint256
    cpu: DynArray[CoinPriceUSD, 50]
    expireTimestamp: uint256

interface AddressRegistry:
    def coinToStrategy(a: address) -> DynArray[address,100]: view

interface IERC20:
    def transferFrom(a: address, b: address, c: uint256) -> bool: nonpayable
    def balanceOf(a: address) -> uint256: view

interface IVault:
    def deposit(dwp: DepositWithdrawalParams): payable
    def withdraw(dwp: DepositWithdrawalParams): payable
    def claimDebt(a: address, b: uint256): nonpayable
    def transferFrom(a: address, b: address, c: uint256) -> bool: nonpayable

struct MintRequest:
    inputTokenAmount: uint256
    minAlpAmount: uint256
    coin: IERC20
    requester: address
    expire: uint256

struct BurnRequest:
    maxAlpAmount: uint256
    outputTokenAmount: uint256
    coin: IERC20
    requester: address
    expire: uint256

struct CoinPriceUSD:
    coin: address
    price: uint256

mintQueue: DynArray[MintRequest, 200]
burnQueue: DynArray[BurnRequest, 200]
owner: address
lock: bool
vault: address
addressRegistry: AddressRegistry

@external
def __init__(_vault: address, _addressRegistry: AddressRegistry):
    self.owner = msg.sender
    self.vault = _vault
    self.addressRegistry = _addressRegistry

# request vault to mint ALP tokens and sends payment tokens to vault afterwards
@external 
@nonreentrant("router")
def processMintRequest(dwp: DepositWithdrawalParams):
    assert msg.sender == self.owner
    assert self.lock
    mr: MintRequest = self.mintQueue.pop()
    assert block.timestamp < mr.expire
    assert mr.inputTokenAmount == dwp._amount
    before_balance: uint256 = IERC20(self.vault).balanceOf(self)
    IVault(self.vault).deposit(dwp)
    after_balance: uint256 = IERC20(self.vault).balanceOf(self)
    delta: uint256 = after_balance - before_balance
    assert delta > mr.minAlpAmount
    if mr.coin.address == convert(0, address):
        send(self.vault, mr.inputTokenAmount)
    else:
        assert mr.coin.transferFrom(self, self.vault, mr.inputTokenAmount)
    assert IERC20(self.vault).transferFrom(self, mr.requester, mr.minAlpAmount)

@external
@nonreentrant("router")
def cancelMintRequest(refund: bool):
    assert self.lock
    mr: MintRequest = self.mintQueue.pop()
    assert msg.sender == self.owner or mr.expire < block.timestamp
    if refund:
        if mr.coin.address == convert(0, address):
            send(mr.requester, mr.inputTokenAmount)
        else:
            assert mr.coin.transferFrom(self, msg.sender, mr.inputTokenAmount)

# request vault to burn ALP tokens and mint debt tokens to requester afterwards.
@external 
@nonreentrant("router")
def processBurnRequest(dwp: DepositWithdrawalParams):
    assert msg.sender == self.owner
    assert self.lock
    br: BurnRequest = self.burnQueue.pop()
    assert block.timestamp < br.expire
    assert br.outputTokenAmount == dwp._amount
    before_balance: uint256 = IERC20(self.vault).balanceOf(self)
    IVault(self.vault).withdraw(dwp)
    after_balance: uint256 = IERC20(self.vault).balanceOf(self)
    delta: uint256 = before_balance - after_balance
    assert delta < br.maxAlpAmount
    IVault(self.vault).claimDebt(dwp.cpu[dwp.coinPositionInCPU].coin, dwp._amount)
    if br.coin.address == convert(0, address):
        send(br.requester, br.outputTokenAmount)
    else:
        br.coin.transferFrom(self, br.requester, br.outputTokenAmount)

@external
@nonreentrant("router")
def refundBurnRequest():
    assert self.lock
    br: BurnRequest = self.burnQueue.pop()
    assert msg.sender == self.owner or br.expire < block.timestamp
    assert IERC20(self.vault).transferFrom(self, msg.sender, br.maxAlpAmount)

# lock submitting new requests before crunching queue
@external 
def acquireLock():
    assert msg.sender == self.owner
    self.lock = True

@external 
def releaseLock():
    assert msg.sender == self.owner
    self.lock = False

@external
@nonreentrant("router")
@payable
def submitMintRequest(mr: MintRequest):
    assert len(self.addressRegistry.coinToStrategy(mr.coin.address)) > 0
    assert self.lock == False
    assert mr.requester == msg.sender
    self.mintQueue.append(mr)
    if convert(0, address) != mr.coin.address:
        assert mr.coin.transferFrom(msg.sender, self, mr.inputTokenAmount)
    else:
        assert msg.value == mr.inputTokenAmount

@external
@nonreentrant("router")
def submitBurnRequest(br: BurnRequest):
    assert len(self.addressRegistry.coinToStrategy(br.coin.address)) > 0
    assert self.lock == False
    assert br.requester == msg.sender
    self.burnQueue.append(br)
    assert IERC20(self.vault).transferFrom(msg.sender, self, br.maxAlpAmount)

@external
@nonreentrant("router")
def rescueStuckTokens(token: IERC20, amount: uint256):
    assert msg.sender == self.owner
    assert token.transferFrom(self, self.owner, amount)

@external
def suicide():
    assert msg.sender == self.owner
    selfdestruct(self.owner)
# @version 0.3.8

struct CoinPriceUSD:
    coin: address
    price: uint256

struct DepositWithdrawalParams:
    coinPositionInCPU: uint256
    _amount: uint256
    cpu: DynArray[CoinPriceUSD, 50]
    expireTimestamp: uint256

struct OracleParams:
    cpu: DynArray[CoinPriceUSD, 50]
    expireTimestamp: uint256

interface AddressRegistry:
    def getCoinToStrategy(a: address) -> DynArray[address,100]: view

interface IERC20:
    def transferFrom(a: address, b: address, c: uint256) -> bool: nonpayable
    def balanceOf(a: address) -> uint256: view
    def transfer(a: address, c: uint256) -> bool: nonpayable

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

mintQueue: DynArray[MintRequest, 200]
burnQueue: DynArray[BurnRequest, 200]
owner: public(address)
lock: bool
vault: address
addressRegistry: AddressRegistry

@external
def initialize(_vault: address, _addressRegistry: AddressRegistry):
    assert self.owner == empty(address)
    self.owner = msg.sender
    self.vault = _vault
    self.addressRegistry = _addressRegistry

@internal
def getCoinPositionInCPU(cpu: DynArray[CoinPriceUSD, 50], coin: address) -> uint256:
    for i in range(50):
        if i < len(cpu) and cpu[i].coin == coin:
            return i
    raise "False"

# request vault to mint ALP tokens and sends payment tokens to vault afterwards
@external 
@nonreentrant("router")
def processMintRequest(dwp: OracleParams):
    assert msg.sender == self.owner
    if not self.lock:
        raise "Not locked"
    if not len(self.mintQueue) > 0:
        raise "No mint request"
    mr: MintRequest = self.mintQueue.pop()
    if block.timestamp > mr.expire:
        raise "Request expired"
    before_balance: uint256 = IERC20(self.vault).balanceOf(self)
    IVault(self.vault).deposit(DepositWithdrawalParams({
        coinPositionInCPU: self.getCoinPositionInCPU(dwp.cpu, mr.coin.address),
        _amount: mr.inputTokenAmount,
        cpu: dwp.cpu,
        expireTimestamp: dwp.expireTimestamp
    }))
    after_balance: uint256 = IERC20(self.vault).balanceOf(self)
    delta: uint256 = after_balance - before_balance
    if delta < mr.minAlpAmount:
        raise "Not enough ALP minted"
    if mr.coin.address == convert(0, address):
        send(self.vault, mr.inputTokenAmount)
    else:
        assert mr.coin.transfer(self.vault, mr.inputTokenAmount)
    assert IERC20(self.vault).transfer(mr.requester, mr.minAlpAmount)

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
            assert mr.coin.transfer(msg.sender, mr.inputTokenAmount)

# request vault to burn ALP tokens and mint debt tokens to requester afterwards.
@external 
@nonreentrant("router")
def processBurnRequest(dwp: OracleParams):
    if not self.lock:
        raise "Not locked"
    if not len(self.burnQueue) > 0:
        raise "No burn request"
    br: BurnRequest = self.burnQueue.pop()
    if block.timestamp > br.expire:
        raise "Request expired"
    before_balance: uint256 = IERC20(self.vault).balanceOf(self)
    coinPositionInCPU: uint256 = self.getCoinPositionInCPU(dwp.cpu, br.coin.address)
    IVault(self.vault).withdraw(DepositWithdrawalParams({
        coinPositionInCPU: coinPositionInCPU,
        _amount: br.outputTokenAmount,
        cpu: dwp.cpu,
        expireTimestamp: dwp.expireTimestamp
    }))
    after_balance: uint256 = IERC20(self.vault).balanceOf(self)
    delta: uint256 = before_balance - after_balance
    if delta > br.maxAlpAmount:
        raise "Too much ALP burned"
    IVault(self.vault).claimDebt(dwp.cpu[coinPositionInCPU].coin, br.outputTokenAmount)
    if br.coin.address == convert(0, address):
        send(br.requester, br.outputTokenAmount)
    else:
        br.coin.transfer(br.requester, br.outputTokenAmount)

@external
@nonreentrant("router")
def refundBurnRequest():
    assert self.lock
    br: BurnRequest = self.burnQueue.pop()
    assert msg.sender == self.owner or br.expire < block.timestamp
    assert IERC20(self.vault).transfer(msg.sender, br.maxAlpAmount)

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
    assert len(self.addressRegistry.getCoinToStrategy(mr.coin.address)) > 0
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
    assert len(self.addressRegistry.getCoinToStrategy(br.coin.address)) > 0
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
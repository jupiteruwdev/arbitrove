# @version 0.3.7

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

interface FeeOracle:
    def isInTarget(coin: address) -> bool: view

interface AddressRegistry:
    def getCoinToStrategy(a: address) -> DynArray[address,100]: view
    def feeOracle() -> FeeOracle: view

interface IERC20:
    def transferFrom(a: address, b: address, c: uint256) -> bool: nonpayable
    def balanceOf(a: address) -> uint256: view
    def transfer(a: address, c: uint256) -> bool: nonpayable

interface IVault:
    def deposit(dwp: DepositWithdrawalParams): nonpayable
    def withdraw(dwp: DepositWithdrawalParams): nonpayable
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
darkOracle: public(address)
fee: public(uint256)
feeDenominator: public(uint256)
burntAmounts: public(HashMap[address, uint256])
lock: bool
vault: address
addressRegistry: AddressRegistry
event MintRequestAdded:
    mr: MintRequest
event BurnRequestAdded:
    br: BurnRequest
event MintRequestProcessed:
    op: OracleParams
event BurnRequestProcessed:
    op: OracleParams
event MintRequestCanceled:
    mr: MintRequest
event BurnRequestRefunded:
    br: BurnRequest
event Initialized:
    vault: indexed(address)
    addressRegistry: AddressRegistry
    darkOracle: indexed(address)
event Suicide: pass

@external
def __init__(_vault: address, _addressRegistry: AddressRegistry, _darkOracle: address):
    assert not _vault == convert(0, address), "Invalid _vault address"
    assert not _darkOracle == convert(0, address), "Invalid _darkOracle address"
    self.owner = msg.sender
    self.vault = _vault
    self.addressRegistry = _addressRegistry
    self.darkOracle = _darkOracle
    log Initialized(_vault, _addressRegistry, _darkOracle)

@external
def reinitialize(_vault: address, _addressRegistry: AddressRegistry, _darkOracle: address):
    assert msg.sender == self.owner, "Not a permitted user"
    assert not _vault == convert(0, address), "Invalid _vault address"
    assert not _darkOracle == convert(0, address), "Invalid _darkOracle address"
    self.vault = _vault
    self.addressRegistry = _addressRegistry
    self.darkOracle = _darkOracle

@external
def setFee(_fee: uint256):
    assert msg.sender == self.owner, "Not a permitted user"
    self.fee = _fee

@external
def setFeeDenominator(_feeDenominator: uint256):
    assert msg.sender == self.owner, "Not a permitted user"
    self.feeDenominator = _feeDenominator

# request vault to mint ALP tokens and sends payment tokens to vault afterwards
@external 
@nonreentrant("router")
def processMintRequest(dwp: OracleParams):
    assert self.addressRegistry.feeOracle().isInTarget(dwp.cpu[0].coin), "Invalid coin for oracle"
    assert msg.sender == self.darkOracle, "Not a permitted user"
    if not self.lock:
        raise "Not locked"
    if not len(self.mintQueue) > 0:
        raise "No mint request"
    mr: MintRequest = self.mintQueueFirstPop()
    if block.timestamp > mr.expire:
        raise "Request expired"
    before_balance: uint256 = IERC20(self.vault).balanceOf(self)
    _amountToMint: uint256 = mr.inputTokenAmount
    if self.fee > 0:
        if self.feeDenominator < self.fee:
            raise "Invalid feeDenominator"
        _amountToMint = _amountToMint * (self.feeDenominator - self.fee) / self.feeDenominator
    IVault(self.vault).deposit(DepositWithdrawalParams({
        coinPositionInCPU: self.getCoinPositionInCPU(dwp.cpu, mr.coin.address),
        _amount: _amountToMint,
        cpu: dwp.cpu,
        expireTimestamp: dwp.expireTimestamp
    }))
    after_balance: uint256 = IERC20(self.vault).balanceOf(self)
    delta: uint256 = after_balance - before_balance
    if delta < mr.minAlpAmount:
        raise "Not enough ALP minted"
    if mr.coin.address == convert(0, address):
        send(self.vault, _amountToMint)
    else:
        assert mr.coin.transfer(self.vault, _amountToMint), "Coin transfer failed"
    assert IERC20(self.vault).transfer(mr.requester, delta, default_return_value=True), "ALP transfer failed"
    log MintRequestProcessed(dwp)

@external
@nonreentrant("router")
def cancelMintRequest(refund: bool):
    assert self.lock, "Not locked"
    if not len(self.mintQueue) > 0:
        raise "No mint request"
    assert msg.sender == self.darkOracle, "Not a permitted user"
    mr: MintRequest = self.mintQueueFirstPop()
    if refund:
        if mr.coin.address == convert(0, address):
            send(mr.requester, mr.inputTokenAmount)
        else:
            assert mr.coin.transfer(mr.requester, mr.inputTokenAmount, default_return_value=True)
    log MintRequestCanceled(mr)

# request vault to burn ALP tokens and mint debt tokens to requester afterwards.
@external 
@nonreentrant("router")
def processBurnRequest(dwp: OracleParams):
    assert self.addressRegistry.feeOracle().isInTarget(dwp.cpu[0].coin), "Invalid coin for oracle"
    assert msg.sender == self.darkOracle, "Not a permitted user"
    if not self.lock:
        raise "Not locked"
    if not len(self.burnQueue) > 0:
        raise "No burn request"
    br: BurnRequest = self.burnQueueFirstPop()
    if block.timestamp > br.expire:
        raise "Request expired"
    before_balance: uint256 = IERC20(self.vault).balanceOf(self)
    _amountToBurn: uint256 = br.outputTokenAmount
    if self.fee > 0:
        if self.feeDenominator < self.fee:
            raise "Invalid feeDenominator"
        _amountToBurn = _amountToBurn * (self.feeDenominator - self.fee) / self.feeDenominator
    coinPositionInCPU: uint256 = self.getCoinPositionInCPU(dwp.cpu, br.coin.address)
    IVault(self.vault).withdraw(DepositWithdrawalParams({
        coinPositionInCPU: coinPositionInCPU,
        _amount: _amountToBurn,
        cpu: dwp.cpu,
        expireTimestamp: dwp.expireTimestamp
    }))
    after_balance: uint256 = IERC20(self.vault).balanceOf(self)
    delta: uint256 = before_balance - after_balance
    if delta > br.maxAlpAmount:
        raise "Too much ALP burned"
    IVault(self.vault).claimDebt(dwp.cpu[coinPositionInCPU].coin, _amountToBurn)
    if br.coin.address == convert(0, address):
        send(br.requester, _amountToBurn)
    else:
        assert br.coin.transfer(br.requester, _amountToBurn), "Coin transfer failed"
    assert IERC20(self.vault).transfer(br.requester, br.maxAlpAmount - delta, default_return_value=True), "ALP transfer failed"
    log BurnRequestProcessed(dwp)

@external
def refundBack():
    amount: uint256 = self.burntAmounts[msg.sender]
    assert amount > 0, "No funds to back"
    self.burntAmounts[msg.sender] = 0
    send(msg.sender, amount)

@external
@nonreentrant("router")
def refundBurnRequest():
    assert self.lock, "Not locked"
    if not len(self.burnQueue) > 0:
        raise "No burn request"
    br: BurnRequest = self.burnQueueFirstPop()
    assert msg.sender == self.darkOracle, "Not a permitted user"
    assert IERC20(self.vault).transfer(br.requester, br.maxAlpAmount, default_return_value=True), "ALP transfer failed"
    log BurnRequestRefunded(br)

# lock submitting new requests before crunching queue
@external 
def acquireLock():
    assert msg.sender == self.darkOracle, "Not a permitted user"
    self.lock = True

@external 
def releaseLock():
    assert msg.sender == self.darkOracle, "Not a permitted user"
    self.lock = False

@external
@nonreentrant("router")
@payable
def submitMintRequest(mr: MintRequest):
    
    assert self.addressRegistry.feeOracle().isInTarget(mr.coin.address), "Invalid coin for oracle"
    assert self.lock == False, "Locked"
    assert mr.requester == msg.sender, "Invalid requester"
    self.mintQueue.append(mr)
    if convert(0, address) != mr.coin.address:
        assert mr.coin.transferFrom(msg.sender, self, mr.inputTokenAmount), "Coin transfer failed"
    else:
        assert msg.value == mr.inputTokenAmount, "Invalid input token amount"
    log MintRequestAdded(mr)


@external
@nonreentrant("router")
def submitBurnRequest(br: BurnRequest):
    assert self.addressRegistry.feeOracle().isInTarget(br.coin.address), "Invalid coin for oracle"
    assert self.lock == False, "Locked"
    assert br.requester == msg.sender, "Invalid requester"
    self.burnQueue.append(br)
    assert IERC20(self.vault).transferFrom(msg.sender, self, br.maxAlpAmount), "ALP transfer failed"
    log BurnRequestAdded(br)

@external
@nonreentrant("router")
def rescueStuckTokens(token: IERC20, amount: uint256):
    assert msg.sender == self.owner, "Not a permitted user"
    assert token.transfer(self.owner, amount, default_return_value=True), "Token transfer failed"

@external
def suicide():
    assert msg.sender == self.owner, "Not a permitted user"
    log Suicide()
    selfdestruct(self.owner)

@external
@view
def mintQueueLength() -> uint256:
    return len(self.mintQueue)

@external
@view
def burnQueueLength() -> uint256:
    return len(self.burnQueue)


@internal
def getCoinPositionInCPU(cpu: DynArray[CoinPriceUSD, 50], coin: address) -> uint256:
    position: uint256 = 0

    for coinPrice in cpu:
        if coinPrice.coin == coin:
            return position
        position = position + 1
    raise "False"

@internal
def mintQueueFirstPop() -> MintRequest:
    firstMr: MintRequest = self.mintQueue[0]
    newMintQueue: DynArray[MintRequest, 200] = []
    position: uint256 = 0

    for mr in self.mintQueue:
        if position > 0:
            newMintQueue.append(mr)
        position = position + 1
    
    self.mintQueue = newMintQueue
    return firstMr

@internal
def burnQueueFirstPop() -> BurnRequest:
    firstBr: BurnRequest = self.burnQueue[0]
    newBurnQueue: DynArray[BurnRequest, 200] = []
    position: uint256 = 0

    for br in self.burnQueue:
        if position > 0:
            newBurnQueue.append(br)
        position = position + 1
    
    self.burnQueue = newBurnQueue
    return firstBr

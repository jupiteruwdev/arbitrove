# @version 0.3.8

interface IERC20:
    def transferFrom(a: address, b: address, c: uint256) -> bool: nonpayable
    def balanceOf(a: address) -> uint256: view

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
owner: address
lock: bool
vault: address

@external
def __init__(_vault: address):
    self.owner = msg.sender
    self.vault = _vault

# request vault to mint ALP tokens and sends payment tokens to vault afterwards
@external 
def processMintRequest():
    assert msg.sender == self.owner
    assert self.lock
    mr: MintRequest = self.mintQueue.pop()
    before_balance: uint256 = IERC20(self.vault).balanceOf(self)
    # todo: mint the ALP token
    after_balance: uint256 = IERC20(self.vault).balanceOf(self)
    delta: uint256 = after_balance - before_balance
    assert delta > mr.minAlpAmount
    mr.coin.transferFrom(self, self.vault, mr.inputTokenAmount)
    IERC20(self.vault).transferFrom(self, mr.requester, delta)


# request vault to burn ALP tokens and mint debt tokens to requester afterwards.
@external 
def processBurnRequest():
    assert msg.sender == self.owner
    assert self.lock
    br: BurnRequest = self.burnQueue.pop()
    before_balance: uint256 = IERC20(self.vault).balanceOf(self)
    # todo: mint the ALP token
    after_balance: uint256 = IERC20(self.vault).balanceOf(self)
    delta: uint256 = before_balance - after_balance
    assert delta < br.maxAlpAmount
    # todo: claim the debt
    br.coin.transferFrom(self, br.requester, br.outputTokenAmount)\

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
def submitMintRequest(mr: MintRequest):
    assert self.lock == False
    assert mr.requester == msg.sender
    self.mintQueue.append(mr)
    mr.coin.transferFrom(msg.sender, self, mr.inputTokenAmount)

@external
def submitBurnRequest(br: BurnRequest):
    assert self.lock == False
    assert br.requester == msg.sender
    self.burnQueue.append(br)
    IERC20(self.vault).transferFrom(msg.sender, self, br.maxAlpAmount)

@external
def rescueStuckTokens(token: IERC20, amount: uint256):
    assert msg.sender == self.owner
    token.transferFrom(self, self.owner, amount)

@external
def suicide():
    assert msg.sender == self.owner
    selfdestruct(self.owner)
# @version 0.3.8

interface IERC20:
    def transferFrom(a: address, b: address, c: uint256) -> bool: nonpayable

struct MintRequest:
    inputTokenAmount: uint256
    minAlpAmount: uint256
    coin: IERC20
    requester: address
    expire: uint256

struct BurnRequest:
    inputAlpAmount: uint256
    minTokenAmount: uint256
    coin: IERC20
    requester: address
    expire: uint256

mintQueue: DynArray[MintRequest, 200]
burnQueue: DynArray[BurnRequest, 200]
owner: address
lock: bool

@external
def __init__():
    self.owner = msg.sender

# request vault to mint ALP tokens and sends payment tokens to vault afterwards
@external 
def processMintRequest():
    assert msg.sender == self.owner
    assert self.lock

# request vault to burn ALP tokens and mint debt tokens to requester afterwards.
@external 
def processBurnRequest():
    assert msg.sender == self.owner
    assert self.lock

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
    self.mintQueue.append(mr)
    mr.coin.transferFrom(msg.sender, self, mr.inputTokenAmount)

@external
def submitBurnRequest(br: BurnRequest):
    assert self.lock == False
    self.burnQueue.append(br)


@external
def suicide():
    assert msg.sender == self.owner
    selfdestruct(self.owner)
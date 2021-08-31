const assert = require('assert');
const { ethers } = require('hardhat');

describe('Ethernauts.mint', () => {
  let Ethernauts;

  let users;

  let user;
  let tx, receipt;
  let mintedTokenId;
  let tokensMinted = 0;

  before('identify signers', async () => {
    users = await ethers.getSigners();
  });

  before('deploy contract', async () => {
    const factory = await ethers.getContractFactory('Ethernauts');
    Ethernauts = await factory.deploy();
  });

  function itCorrectlyMintsTokensForUser(userNumber) {
    describe(`when minting a token for user #${userNumber}`, () => {

      before('identify the user', async () => {
        user = users[userNumber];
      });

      before('keep track of values', async () => {
        if (!user.numTokens) user.numTokens = 0;
        if (!user.tokenIds) user.tokenIds = [];

        mintedTokenId = `${tokensMinted}`;
        user.tokenIds.push(mintedTokenId);

        user.numTokens++;
        tokensMinted++;
      });

      before('record ETH balances', async () => {
        Ethernauts.recordedEthBalance = await ethers.provider.getBalance(Ethernauts.address);
        user.recordedEthBalance = await ethers.provider.getBalance(user.address);
      });

      before('mint', async () => {
        tx = await Ethernauts.connect(user).mint({
          value: ethers.utils.parseEther('1'),
        });

        receipt = await tx.wait();
      });

      it('emitted a Transfer event', async () => {
        const event = receipt.events.find(e => e.event === 'Transfer');

        assert.equal(event.args.from, '0x0000000000000000000000000000000000000000');
        assert.equal(event.args.to, user.address);
        assert.equal(event.args.tokenId.toString(), mintedTokenId);
      });

      it('reduced the user ETH balance', async () => {
        const paidInGas = ethers.BigNumber.from(receipt.cumulativeGasUsed).mul(receipt.effectiveGasPrice);

        assert.deepEqual(
          await ethers.provider.getBalance(user.address),
          user.recordedEthBalance.sub(tx.value).sub(paidInGas)
        );
      });

      it('incremented the contract ETH balance', async () => {
        assert.deepEqual(
          await ethers.provider.getBalance(Ethernauts.address),
          Ethernauts.recordedEthBalance.add(tx.value)
        );
      });

      it('incremented the user token balance', async () => {
        assert.equal(
          await Ethernauts.balanceOf(user.address),
          user.numTokens
        );
      });

      it('shows that the user owns the token', async () => {
        assert.equal(
          await Ethernauts.ownerOf(mintedTokenId),
          user.address
        );
      });
    });
  }

  describe('when minting various tokens', () => {
    itCorrectlyMintsTokensForUser(1);
    itCorrectlyMintsTokensForUser(1);
    itCorrectlyMintsTokensForUser(2);
    itCorrectlyMintsTokensForUser(2);
    itCorrectlyMintsTokensForUser(2);
    itCorrectlyMintsTokensForUser(1);
    itCorrectlyMintsTokensForUser(3);
    itCorrectlyMintsTokensForUser(4);
    itCorrectlyMintsTokensForUser(1);
    itCorrectlyMintsTokensForUser(5);
    itCorrectlyMintsTokensForUser(2);
    itCorrectlyMintsTokensForUser(6);
    itCorrectlyMintsTokensForUser(1);
    itCorrectlyMintsTokensForUser(2);
    itCorrectlyMintsTokensForUser(5);
    itCorrectlyMintsTokensForUser(3);
  });
});
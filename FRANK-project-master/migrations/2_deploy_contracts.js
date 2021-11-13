const FRANK = artifacts.require('./FRANK.sol')

module.exports = async (deployer, network, addresses) => {
  deployer.deploy(FRANK, ["0x9A477F66B8676CCc80084Fcb2b2a75281FE76c13"], [3])
}

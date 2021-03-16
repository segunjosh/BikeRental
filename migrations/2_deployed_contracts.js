const BorrowSystem = artifacts.require("./BorrowSystem.sol");
const LoanSystem = artifacts.require("./LoanSystem.sol");
module.exports = function(deployer) {
  deployer.deploy(BorrowSystem);
  deployer.deploy(LoanSystem);
};

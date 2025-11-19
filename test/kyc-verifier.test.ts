import { expect } from 'chai'
import { ethers } from 'hardhat'
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { Reclaim } from '../src/types'
import {
    deployReclaimContract,
    generateMockWitnessesList,
    randomWallet,
    randomiseWitnessList
} from './utils'
import {
    CompleteClaimData,
    createSignDataForClaim,
    fetchWitnessListForClaim,
    hashClaimInfo
} from '@reclaimprotocol/crypto-sdk'
import fs from 'fs'
import path from 'path'

describe('KYCVerifier and KYCNFT Tests', () => {
    const NUM_WITNESSES = 5
    const MOCK_HOST_PREFIX = 'localhost:555'
    const NFT_NAME = 'KYC Certificate'
    const NFT_SYMBOL = 'KYC-CERT'

    async function verifierFixture() {
        const signers = await ethers.getSigners()
        const owner = signers[0]
        const user = await randomWallet(40, ethers.provider)

        // Deploy Reclaim contract
        const reclaimContract = await deployReclaimContract(ethers, owner)

        // Generate witnesses
        const { mockWitnesses, witnessesWallets } = await generateMockWitnessesList(
            NUM_WITNESSES,
            MOCK_HOST_PREFIX,
            ethers
        )
        const witnesses = await randomiseWitnessList(mockWitnesses)

        // Add epoch
        await reclaimContract.addNewEpoch(witnesses, 5)
        const currentEpoch = await reclaimContract.currentEpoch()

        // Load the example binance claim JSON
        const jsonPath = path.join(__dirname, '../contracts/example-binance-claim.json')
        const claimData = JSON.parse(fs.readFileSync(jsonPath, 'utf-8'))

        // Extract data from JSON
        const claimInfo = {
            provider: claimData.claimData.provider,
            parameters: claimData.claimData.parameters,
            context: claimData.claimData.context
        }

        // Create claim data with the epoch from the deployed contract
        const identifier = hashClaimInfo(claimInfo)
        const timestampS = claimData.claimData.timestampS
        const epoch = currentEpoch

        // Get the expected witnesses for this claim
        const resolvedWitnesses = await Promise.all(
            witnesses.map(async w => ({
                id: typeof w.addr === 'string' ? w.addr : await w.addr,
                url: typeof w.host === 'string' ? w.host : await w.host
            }))
        )
        const expectedWitnesses = await fetchWitnessListForClaim(
            {
                epoch: epoch,
                witnesses: resolvedWitnesses,
                witnessesRequiredForClaim: 5,
                nextEpochTimestampS: 0
            },
            identifier,
            timestampS
        )

        // Generate signatures from the witnesses
        const claimDataForSigning: CompleteClaimData = {
            identifier: identifier,
            owner: user.address, // Use the test user's address
            timestampS: timestampS,
            epoch: epoch
        }

        const claimDataStr = createSignDataForClaim(claimDataForSigning)
        const signatures = await Promise.all(
            expectedWitnesses.map(async w => {
                // Find the wallet by matching address case-insensitively
                const witnessAddr = w.id.toLowerCase()
                let wallet = witnessesWallets[w.id] // Try exact match first
                if (!wallet) {
                    // Try case-insensitive lookup
                    const walletKey = Object.keys(witnessesWallets).find(
                        key => key.toLowerCase() === witnessAddr
                    )
                    if (walletKey) {
                        wallet = witnessesWallets[walletKey]
                    }
                }
                if (!wallet) {
                    throw new Error(`Witness wallet not found for ${w.id}. Available: ${Object.keys(witnessesWallets).join(', ')}`)
                }
                return wallet.signMessage(claimDataStr)
            })
        )

        // Construct the proof
        const proof: Reclaim.ProofStruct = {
            claimInfo: {
                provider: claimInfo.provider,
                parameters: claimInfo.parameters,
                context: claimInfo.context
            },
            signedClaim: {
                claim: {
                    identifier: identifier,
                    owner: user.address, // Use the test user's address
                    timestampS: timestampS,
                    epoch: epoch
                },
                signatures: signatures
            }
        }

        // Deploy Claims library first
        const ClaimsLibraryFactory = await ethers.getContractFactory('Claims')
        const claimsLibrary = await ClaimsLibraryFactory.deploy()
        await claimsLibrary.deployed()

        // Deploy KYCNFT contract
        const NFTContractFactory = await ethers.getContractFactory('KYCNFT')
        const nftContract = await NFTContractFactory.deploy(NFT_NAME, NFT_SYMBOL)
        await nftContract.deployed()

        // Deploy KYCVerifier contract with linked Claims library
        const VerifierContractFactory = await ethers.getContractFactory('KYCVerifier', {
            libraries: {
                Claims: claimsLibrary.address
            }
        })
        const verifierContract = await VerifierContractFactory.deploy(
            reclaimContract.address,
            nftContract.address
        )
        await verifierContract.deployed()

        // Authorize the verifier to mint NFTs
        await nftContract.connect(owner).setAuthorizedMinter(verifierContract.address, true)

        return {
            reclaimContract,
            nftContract,
            verifierContract,
            proof,
            user,
            owner,
            witnesses,
            witnessesWallets
        }
    }

    describe('KYCVerifier', () => {
        it('should verify proof and mint NFT for Binance platform', async () => {
            const { verifierContract, nftContract, proof, user } = await loadFixture(verifierFixture)

            // Verify and mint
            await expect(
                verifierContract.connect(user).verifyAndMint(proof, 'binance', user.address)
            )
                .to.emit(nftContract, 'KYCNFTMinted')
                .withArgs(user.address, 0, 'Jure', 'Snoj', 'ADVANCED', 'binance')

            // Check that NFT was minted
            expect(await nftContract.ownerOf(0)).to.equal(user.address)
            expect(await nftContract.balanceOf(user.address)).to.equal(1)
        })

        it('should store KYC data correctly with platform information', async () => {
            const { verifierContract, nftContract, proof, user } = await loadFixture(verifierFixture)

            // Verify and mint
            await verifierContract.connect(user).verifyAndMint(proof, 'binance', user.address)

            // Get KYC data
            const kycData = await nftContract.getKYCData(0)

            expect(kycData.firstName).to.equal('Jure')
            expect(kycData.lastName).to.equal('Snoj')
            expect(kycData.kycStatus).to.equal('ADVANCED')
            expect(kycData.platform).to.equal('binance')
            expect(kycData.verifiedAddress).to.equal(user.address)
            expect(kycData.mintedAt).to.be.gt(0)
        })

        it('should reject proof if owner does not match recipient', async () => {
            const { verifierContract, proof, user } = await loadFixture(verifierFixture)
            const signers = await ethers.getSigners()
            const otherUser = signers[1]

            // Try to mint to a different address than the proof owner
            await expect(
                verifierContract.connect(user).verifyAndMint(proof, 'binance', otherUser.address)
            ).to.be.revertedWith('Proof owner must match recipient address')
        })

        it('should reject if platform is not registered', async () => {
            const { verifierContract, proof, user } = await loadFixture(verifierFixture)

            // Try to verify with unregistered platform
            await expect(
                verifierContract.connect(user).verifyAndMint(proof, 'coinbase', user.address)
            ).to.be.revertedWith('Platform not registered')
        })

        it('should allow owner to register new platform', async () => {
            const { verifierContract, owner } = await loadFixture(verifierFixture)

            // Register a new platform
            await verifierContract.connect(owner).registerPlatform(
                'coinbase',
                '"kycLevel":"',
                '"firstName":"',
                '"lastName":"'
            )

            // Check platform config
            const config = await verifierContract.getPlatformConfig('coinbase')
            expect(config.isActive).to.be.true
            expect(config.kycStatusField).to.equal('"kycLevel":"')
        })

        it('should allow owner to deactivate platform', async () => {
            const { verifierContract, owner, proof, user } = await loadFixture(verifierFixture)

            // Deactivate binance platform
            await verifierContract.connect(owner).updatePlatformStatus('binance', false)

            // Try to verify with deactivated platform
            await expect(
                verifierContract.connect(user).verifyAndMint(proof, 'binance', user.address)
            ).to.be.revertedWith('Platform is not active')
        })

        it('should emit KYCVerified event', async () => {
            const { verifierContract, proof, user } = await loadFixture(verifierFixture)

            await expect(
                verifierContract.connect(user).verifyAndMint(proof, 'binance', user.address)
            )
                .to.emit(verifierContract, 'KYCVerified')
                .withArgs(user.address, 'binance', 'Jure', 'Snoj', 'ADVANCED')
        })
    })

    describe('KYCNFT', () => {
        it('should prevent duplicate minting for the same address', async () => {
            const { verifierContract, nftContract, proof, user } = await loadFixture(verifierFixture)

            // Mint first NFT
            await verifierContract.connect(user).verifyAndMint(proof, 'binance', user.address)

            // Try to mint again with the same address
            await expect(
                verifierContract.connect(user).verifyAndMint(proof, 'binance', user.address)
            ).to.be.revertedWith('Address already has a KYC NFT')
        })

        it('should return correct token ID for address', async () => {
            const { verifierContract, nftContract, proof, user } = await loadFixture(verifierFixture)

            // Verify and mint
            await verifierContract.connect(user).verifyAndMint(proof, 'binance', user.address)

            // Check token ID
            const tokenId = await nftContract.getTokenIdByAddress(user.address)
            expect(tokenId).to.equal(0)
        })

        it('should check if address has KYC NFT', async () => {
            const { verifierContract, nftContract, proof, user } = await loadFixture(verifierFixture)
            const signers = await ethers.getSigners()
            const otherUser = signers[1]

            // Before minting
            expect(await nftContract.hasKYCNFT(user.address)).to.be.false

            // Verify and mint
            await verifierContract.connect(user).verifyAndMint(proof, 'binance', user.address)

            // After minting
            expect(await nftContract.hasKYCNFT(user.address)).to.be.true
            expect(await nftContract.hasKYCNFT(otherUser.address)).to.be.false
        })

        it('should return correct total supply', async () => {
            const { verifierContract, nftContract, proof, user } = await loadFixture(verifierFixture)

            // Initially zero
            expect(await nftContract.totalSupply()).to.equal(0)

            // Verify and mint
            await verifierContract.connect(user).verifyAndMint(proof, 'binance', user.address)

            // Should be one
            expect(await nftContract.totalSupply()).to.equal(1)
        })

        it('should prevent unauthorized addresses from minting', async () => {
            const { nftContract, user } = await loadFixture(verifierFixture)

            // Try to mint directly (should fail)
            await expect(
                nftContract.connect(user).mint(
                    user.address,
                    'John',
                    'Doe',
                    'VERIFIED',
                    'test'
                )
            ).to.be.revertedWith('Not authorized to mint')
        })

        it('should allow owner to authorize minters', async () => {
            const { nftContract, owner, user } = await loadFixture(verifierFixture)
            const signers = await ethers.getSigners()
            const authorizedMinter = signers[2]

            // Authorize minter
            await nftContract.connect(owner).setAuthorizedMinter(authorizedMinter.address, true)

            // Now minter can mint
            await nftContract.connect(authorizedMinter).mint(
                user.address,
                'John',
                'Doe',
                'VERIFIED',
                'test'
            )

            expect(await nftContract.ownerOf(0)).to.equal(user.address)
        })
    })
})


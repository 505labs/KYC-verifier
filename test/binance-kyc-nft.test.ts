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

describe('BinanceKYCNFT Tests', () => {
    const NUM_WITNESSES = 5
    const MOCK_HOST_PREFIX = 'localhost:555'
    const NFT_NAME = 'Binance KYC Certificate'
    const NFT_SYMBOL = 'BINANCE-KYC'

    async function nftFixture() {
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

        // Deploy KYC contract with the deployed Reclaim address and link the Claims library
        const KYCContractFactory = await ethers.getContractFactory('KYCAttestor', {
            libraries: {
                Claims: claimsLibrary.address
            }
        })
        const kycContract = await KYCContractFactory.deploy(reclaimContract.address)
        await kycContract.deployed()

        // Deploy BinanceKYCNFT contract
        const NFTContractFactory = await ethers.getContractFactory('BinanceKYCNFT')
        const nftContract = await NFTContractFactory.deploy(
            kycContract.address,
            NFT_NAME,
            NFT_SYMBOL
        )
        await nftContract.deployed()

        return {
            reclaimContract,
            kycContract,
            nftContract,
            proof,
            user,
            owner,
            witnesses,
            witnessesWallets
        }
    }

    it('should mint NFT with valid KYC proof', async () => {
        const { nftContract, proof, user } = await loadFixture(nftFixture)

        // Mint NFT
        await expect(nftContract.connect(user).mintWithKYCProof(proof, user.address))
            .to.emit(nftContract, 'KYCNFTMinted')
            .withArgs(user.address, 0, 'Jure', 'Snoj', 'ADVANCED')

        // Check that NFT was minted
        expect(await nftContract.ownerOf(0)).to.equal(user.address)
        expect(await nftContract.balanceOf(user.address)).to.equal(1)
    })

    it('should store KYC data correctly', async () => {
        const { nftContract, proof, user } = await loadFixture(nftFixture)

        // Mint NFT
        await nftContract.connect(user).mintWithKYCProof(proof, user.address)

        // Get KYC data
        const kycData = await nftContract.getKYCData(0)

        expect(kycData.firstName).to.equal('Jure')
        expect(kycData.lastName).to.equal('Snoj')
        expect(kycData.kycStatus).to.equal('ADVANCED')
        expect(kycData.verifiedAddress).to.equal(user.address)
        expect(kycData.mintedAt).to.be.gt(0)
    })

    it('should prevent duplicate minting for the same address', async () => {
        const { nftContract, proof, user } = await loadFixture(nftFixture)

        // Mint first NFT
        await nftContract.connect(user).mintWithKYCProof(proof, user.address)

        // Try to mint again with the same address
        await expect(
            nftContract.connect(user).mintWithKYCProof(proof, user.address)
        ).to.be.revertedWith('Address already has a KYC NFT')
    })

    it('should reject proof if owner does not match recipient', async () => {
        const { nftContract, proof, user } = await loadFixture(nftFixture)
        const signers = await ethers.getSigners()
        const otherUser = signers[1]

        // Try to mint to a different address than the proof owner
        await expect(
            nftContract.connect(user).mintWithKYCProof(proof, otherUser.address)
        ).to.be.revertedWith('Proof owner must match recipient address')
    })

    it('should return correct token ID for address', async () => {
        const { nftContract, proof, user } = await loadFixture(nftFixture)

        // Mint NFT
        await nftContract.connect(user).mintWithKYCProof(proof, user.address)

        // Check token ID
        const tokenId = await nftContract.getTokenIdByAddress(user.address)
        expect(tokenId).to.equal(0)
    })

    it('should check if address has KYC NFT', async () => {
        const { nftContract, proof, user } = await loadFixture(nftFixture)
        const signers = await ethers.getSigners()
        const otherUser = signers[1]

        // Before minting
        expect(await nftContract.hasKYCNFT(user.address)).to.be.false

        // Mint NFT
        await nftContract.connect(user).mintWithKYCProof(proof, user.address)

        // After minting
        expect(await nftContract.hasKYCNFT(user.address)).to.be.true
        expect(await nftContract.hasKYCNFT(otherUser.address)).to.be.false
    })

    it('should return correct total supply', async () => {
        const { nftContract, proof, user } = await loadFixture(nftFixture)

        // Initially zero
        expect(await nftContract.totalSupply()).to.equal(0)

        // Mint NFT
        await nftContract.connect(user).mintWithKYCProof(proof, user.address)

        // Should be one
        expect(await nftContract.totalSupply()).to.equal(1)
    })

    it('should allow owner to update KYCAttestor address', async () => {
        const { nftContract, kycContract, owner } = await loadFixture(nftFixture)
        const signers = await ethers.getSigners()
        const newKYCAddress = signers[2].address

        // Update KYCAttestor address
        await nftContract.connect(owner).setKYCAttestor(newKYCAddress)

        // Verify update
        expect(await nftContract.kycAttestor()).to.equal(newKYCAddress)
    })

    it('should prevent non-owner from updating KYCAttestor address', async () => {
        const { nftContract, user } = await loadFixture(nftFixture)
        const signers = await ethers.getSigners()
        const newKYCAddress = signers[2].address

        // Try to update as non-owner
        await expect(
            nftContract.connect(user).setKYCAttestor(newKYCAddress)
        ).to.be.revertedWith('Ownable: caller is not the owner')
    })
})


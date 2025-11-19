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

describe('KYC Tests', () => {
    const NUM_WITNESSES = 5
    const MOCK_HOST_PREFIX = 'localhost:555'

    async function kycFixture() {
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
            owner: claimData.claimData.owner,
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
                    owner: claimData.claimData.owner,
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

        return {
            reclaimContract,
            kycContract,
            proof,
            user,
            owner,
            witnesses,
            witnessesWallets
        }
    }

    it('should verify proof and extract KYC status from binance claim', async () => {
        const { kycContract, proof, reclaimContract } = await loadFixture(kycFixture)

        // Verify the proof first
        await expect(kycContract.verifyProof(proof)).to.not.be.reverted

        // Test extraction functions
        const [kycStatus, firstName, lastName] = await kycContract.extractBinanceKYCStatus(proof)

        expect(kycStatus).to.equal('ADVANCED')
        expect(firstName).to.equal('Jure')
        expect(lastName).to.equal('Snoj')
    })

    it('should extract KYC level details from binance claim', async () => {
        const { kycContract, proof } = await loadFixture(kycFixture)

        const [kycStatus, firstName, lastName] =
            await kycContract.extractBinanceKYCLevel(proof)

        expect(kycStatus).to.equal('ADVANCED')
        expect(firstName).to.equal('Jure')
        expect(lastName).to.equal('Snoj')
    })
})


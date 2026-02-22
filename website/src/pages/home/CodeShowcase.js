import Link from '@docusaurus/Link';
import Heading from '@theme/Heading';
import Icon from '../../components/ui/Icon';
import styles from './codeShowcase.module.css';

export default function CodeShowcase() {
  return (
    <section className={styles.showcaseSection}>
      <div className="container">
        <div className={styles.showcaseGrid}>
          <div className={styles.showcaseContent}>
            <span className={styles.showcaseBadge}>Shared Storage Architecture</span>
            <Heading as="h2" className={styles.showcaseTitle}>
              Facets and Modules Working Together
            </Heading>
            <p className={styles.showcaseDescription}>
              Both facets and modules access the same storage in your diamond. 
              Your custom facets can extend Compose functionality without inheritance.
            </p>
            <div className={styles.showcaseFeatures}>
              <div className={styles.showcaseFeature}>
                <div className={styles.showcaseFeatureIcon}>
                  <Icon name="showcase-facet" size={24} />
                </div>
                <div>
                  <h4>Facets</h4>
                  <p>Complete, reusable implementations</p>
                </div>
              </div>
              <div className={styles.showcaseFeature}>
                <div className={styles.showcaseFeatureIcon}>
                  <Icon name="showcase-library" size={24} />
                </div>
                <div>
                  <h4>Modules</h4>
                  <p>Helper functions for custom facets</p>
                </div>
              </div>
              <div className={styles.showcaseFeature}>
                <div className={styles.showcaseFeatureIcon}>
                  <Icon name="showcase-storage" size={24} />
                </div>
                <div>
                  <h4>Shared Storage</h4>
                  <p>Both work with the same data</p>
                </div>
              </div>
            </div>
            
            {/* <Link to="/docs/foundations/facets-and-libraries" className={styles.showcaseLink}>
              Learn More
              <Icon name="arrow-right" size={20} />
            </Link> */}
          </div>
          <div className={styles.showcaseCode}>
            <div className={styles.codeWindow}>
              <div className={styles.codeWindowHeader}>
                <span className={styles.codeWindowTitle}>GameNFTFacet.sol</span>
              </div>
              <pre className={styles.codeWindowContent}>
{`// Your custom facet uses the ERC721 module
import { ERC721Mod } from "compose/ERC721Mod.sol";

contract GameNFTFacet {
    function mintWithGameLogic(
        address player,
        uint256 tokenId
    ) external {
        // Your custom game logic
        require(
            playerHasEnoughPoints(player),
            "Not enough points"
        );

        // Use ERC721Mod - same storage
        ERC721Mod.mint(player, tokenId);

        // Standard ERC721Facet functions work seamlessly
        updatePlayerStats(player);
    }
}`}
              </pre>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}




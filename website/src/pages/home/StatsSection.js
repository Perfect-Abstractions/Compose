import {useGithubContributorsCount} from '../../hooks/useGithubContributorsCount';
import Icon from '../../components/ui/Icon';
import styles from './statsSection.module.css';

export default function StatsSection() {
  const {value: contributorsValue} = useGithubContributorsCount({
    owner: 'Perfect-Abstractions',
    repo: 'Compose',
    defaultValue: '17+',
  });

  const stats = [
    { label: 'Open Source', value: 'MIT', icon: 'scroll' },
    { label: 'Diamond Standard', value: 'ERC-2535', icon: 'diamond' },
    { label: 'Contributors', value: contributorsValue, icon: 'community' },
    { label: 'Built with Love', value: 'Community', icon: 'heart' },
  ];

  return (
    <section className={styles.statsSection}>
      <div className="container">
        <div className={styles.statsGrid}>
          {stats.map((stat, idx) => (
            <div key={idx} className={styles.statCard}>
              <div className={styles.statIcon}>
                <Icon name={stat.icon} size={32} />
              </div>
              <div className={styles.statValue}>{stat.value}</div>
              <div className={styles.statLabel}>{stat.label}</div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

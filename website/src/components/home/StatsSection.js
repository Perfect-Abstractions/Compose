import {useGithubContributorsCount} from '../../hooks/useGithubContributorsCount';
import Icon from '../ui/Icon';
import styles from './statsSection.module.css';

export default function StatsSection() {
  const {value: contributorsValue} = useGithubContributorsCount({
    owner: 'Perfect-Abstractions',
    repo: 'Compose',
    defaultValue: '17+',
  });

  const stats = [
    {label: 'Open Source', value: 'MIT', icon: 'scroll'},
    {label: 'Diamond Standard', value: 'ERC-2535', icon: 'diamond'},
    {label: 'Contributors', value: contributorsValue, icon: 'community'},
    {label: 'Built with Love', value: 'Community', icon: 'heart'},
  ];

  return (
    <section className={styles.statsSection} aria-label="Project highlights">
      <div className="container">
        <div className={styles.statsRail}>
          <ul className={styles.statsList}>
            {stats.map((stat) => (
              <li key={stat.label} className={styles.statItem}>
                <span className={styles.statIcon} aria-hidden="true">
                  <Icon name={stat.icon} size={26} />
                </span>
                <span className={styles.statValue}>{stat.value}</span>
                <span className={styles.statLabel}>{stat.label}</span>
              </li>
            ))}
          </ul>
        </div>
      </div>
    </section>
  );
}

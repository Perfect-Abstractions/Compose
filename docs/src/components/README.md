# Components Directory

This directory contains all reusable React components for the Docusaurus documentation site, organized into logical subfolders for better maintainability.

## Directory Structure

### 📁 `ui/` - Basic UI Components
Fundamental, reusable UI building blocks.
- `Accordion` - Collapsible content sections
- `Badge` - Status and category badges
- `Callout` - Informational callout boxes
- `CalloutBox` - Enhanced callout with icons
- `GlassCard` - Card with glass morphism effect
- `GradientButton` - Button with gradient styling
- `GradientText` - Text with gradient effects
- `Tooltip` - Hover tooltip component

### 📁 `docs/` - Documentation-Specific Components
Components designed specifically for documentation pages.
- `DocCard` - Documentation card with links
- `DocHero` - Hero section for doc pages
- `DocSubtitle` - Styled subtitle component
- `LastUpdated` - Shows last update timestamp
- `ReadingTime` - Displays estimated reading time
- `RelatedDocs` - Links to related documentation
- `StepIndicator` - Step-by-step indicators
- `WasThisHelpful` - Feedback component

### 📁 `api/` - API Documentation Components
Components for documenting APIs and technical specifications.
- `ApiEndpoint` - REST API endpoint documentation
- `APIReference` - API reference section
- `ParameterTable` - Function parameter tables
- `PropertyTable` - Object property tables
- `SchemaViewer` - JSON schema viewer

### 📁 `code/` - Code Display Components
Components for displaying and showcasing code.
- `CodeShowcase` - Interactive code examples
- `ExpandableCode` - Collapsible code blocks
- `TerminalCommand` - Terminal command display

### 📁 `data-display/` - Data Visualization Components
Components for displaying data and information visually.
- `ComparisonTable` - Feature comparison tables
- `MermaidDiagram` - Mermaid diagram renderer
- `MetricCard` - Metric/statistic display cards
- `Timeline` - Timeline visualization

### 📁 `features/` - Feature/Homepage Components
Components for feature pages and homepage.
- `FeatureCard` - Feature showcase cards
- `FeatureGrid` - Grid layout for features
- `HomepageFeatures` - Homepage feature section

### 📁 `animations/` - Animation Components
Components with animation effects.
- `AnimatedBackground` - Animated background effects
- `AnimatedCounter` - Animated number counter

### 📁 `navigation/` - Navigation Components
Components for site navigation and header.
- `GitHubStarButton` - GitHub star button
- `NavbarEnhancements` - Navbar enhancement scripts
- `NavbarGradient` - Gradient effect for navbar

## Usage

### Direct Import (from subfolder)
```jsx
import Badge from '@site/src/components/ui/Badge';
import DocHero from '@site/src/components/docs/DocHero';
import CodeShowcase from '@site/src/components/code/CodeShowcase';
```

### Barrel Import (from index.js)
```jsx
import { Badge, DocHero, CodeShowcase } from '@site/src/components';
```

## Adding New Components

When adding a new component:

1. **Choose the appropriate subfolder** based on the component's purpose
2. **Create a folder** for the component: `ComponentName/`
3. **Add files**:
   - `index.js` - Component implementation
   - `styles.module.css` - Component styles
4. **Export from `index.js`** at the root level if needed for barrel exports

## Guidelines

- **Single Responsibility**: Each component should have one clear purpose
- **Reusability**: Components should be generic enough to use across multiple pages
- **Documentation**: Include JSDoc comments for props and usage
- **Styling**: Use CSS modules for component-specific styles
- **Props**: Use TypeScript-style prop documentation even in JSX files

## Maintenance

- Keep components within their appropriate folders
- Update the root `index.js` when adding/moving components
- Document any breaking changes in component interfaces
- Follow the existing code style and patterns


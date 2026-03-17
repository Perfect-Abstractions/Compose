function orderPackageJsonWithDepsBeforeDevDeps(packageJson) {
  const orderedPackageJson = {};
  const dependencies = packageJson.dependencies || {};
  const devDependencies = packageJson.devDependencies || {};
  let insertedDependencyBlocks = false;

  for (const [key, value] of Object.entries(packageJson)) {
    if (key === "dependencies") {
      continue;
    }

    if (key === "devDependencies") {
      orderedPackageJson.dependencies = dependencies;
      orderedPackageJson.devDependencies = devDependencies;
      insertedDependencyBlocks = true;
      continue;
    }

    orderedPackageJson[key] = value;
  }

  if (!insertedDependencyBlocks) {
    orderedPackageJson.dependencies = dependencies;
    orderedPackageJson.devDependencies = devDependencies;
  }

  return orderedPackageJson;
}

module.exports = {
  orderPackageJsonWithDepsBeforeDevDeps,
};

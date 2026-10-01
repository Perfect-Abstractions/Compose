module.exports = {
  test: {
    environment: "node",
    include: ["test/**/*.test.ts"],
    coverage: {
      include: ["src/**/*.ts"],
      exclude: ["src/templates/**"],
      reporter: ["text", "lcov"],
    },
  },
};

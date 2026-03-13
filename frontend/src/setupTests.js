// jest-dom adds custom jest matchers for asserting on DOM nodes.
// allows you to do things like:
// expect(element).toHaveTextContent(/react/i)
// learn more: https://github.com/testing-library/jest-dom
import '@testing-library/jest-dom';

// Mock axios so Jest does not parse ESM entrypoints from node_modules in CI.
jest.mock('axios', () => {
	const instance = {
		defaults: {},
		interceptors: {
			request: { use: jest.fn() },
			response: { use: jest.fn() },
		},
		get: jest.fn(),
		post: jest.fn(),
		put: jest.fn(),
		patch: jest.fn(),
		delete: jest.fn(),
	};

	return {
		create: jest.fn(() => instance),
		...instance,
	};
});

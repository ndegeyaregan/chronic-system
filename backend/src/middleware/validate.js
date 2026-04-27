const { validationResult } = require('express-validator');

const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    console.error('🔴 VALIDATION ERRORS:', {
      path: req.path,
      method: req.method,
      body: req.body,
      errors: errors.array(),
    });
    return res.status(400).json({
      error: 'Validation failed',
      details: errors.array().map(e => ({ field: e.path, message: e.msg, value: e.value })),
    });
  }
  next();
};

module.exports = validate;

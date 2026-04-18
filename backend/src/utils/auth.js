const jwt = require('jsonwebtoken');

const SECRET = () => process.env.JWT_SECRET || 'bitfood-secret-dev';

exports.signToken = (payload) =>
  jwt.sign(payload, SECRET(), { expiresIn: '30d' });

exports.verifyToken = (token) => {
  try {
    return jwt.verify(token, SECRET());
  } catch {
    return null;
  }
};

exports.getUser = (req) => {
  const auth = req?.headers?.authorization || '';
  if (!auth.startsWith('Bearer ')) return null;
  return exports.verifyToken(auth.slice(7));
};

exports.requireAuth = (user) => {
  if (!user) throw new Error('Não autenticado');
};

exports.requireRole = (user, ...roles) => {
  exports.requireAuth(user);
  if (!roles.includes(user.userType))
    throw new Error(`Acesso negado. Requer: ${roles.join(' ou ')}`);
};

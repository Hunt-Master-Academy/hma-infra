const bcrypt = require('bcrypt'); // Use 'bcrypt' instead of 'bcryptjs'

bcrypt.hash('Admin123!HMA', 12)
  .then(hash => {
    console.log('Password hash for Admin123!HMA:');
    console.log(hash);
    process.exit(0);
  })
  .catch(err => {
    console.error('Error:', err);
    process.exit(1);
  });

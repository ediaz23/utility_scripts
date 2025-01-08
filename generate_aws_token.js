
require('cross-fetch/polyfill');
const AmazonCognitoIdentity = require('amazon-cognito-identity-js');
const AWS = require('aws-sdk/global.js');

const email  = ''  // email
const pass = ''  // password

const authenticationData = {
    Username: email,
    Password: pass,
};
const authenticationDetails = new AmazonCognitoIdentity.AuthenticationDetails(
    authenticationData
);
const poolData = {
    UserPoolId: '', // Your user pool id here
    ClientId: '', // Your client id here
};
const userPool = new AmazonCognitoIdentity.CognitoUserPool(poolData);
const userData = {
    Username: email,
    Pool: userPool,
};
const cognitoUser = new AmazonCognitoIdentity.CognitoUser(userData);
cognitoUser.authenticateUser(authenticationDetails, {
    onSuccess: function(result) {
        var accessToken = result.getAccessToken().getJwtToken();
        console.log(`accessToken ${accessToken}`)
    },

    onFailure: function(err) {
        console.log('Error', err, err.message || JSON.stringify(err));
    },

    newPasswordRequired: (userAttributes, requiredAttributes) => {
        console.log('newPasswordRequired', userAttributes, requiredAttributes)
        
        cognitoUser.completeNewPasswordChallenge('newPassword', null, {
            onSuccess: (session) => {
                console.log('Nueva contraseña configurada exitosamente', session);
            },
            onFailure: (err) => {
                console.log('Error al configurar la nueva contraseña', err);
            },
        });
        
        cognitoUser.changePassword('oldPassword', 'newPassword', (err, result) => {
            if (err) {
                console.log('Error al cambiar la contraseña', err)
                return
            }
            console.log('Contraseña cambiada exitosamente', result);
        })
    },
})

<?php
/**
 * The base configuration for WordPress
 *
 * The wp-config.php creation script uses this file during the installation.
 * You don't have to use the web site, you can copy this file to "wp-config.php"
 * and fill in the values.
 *
 * This file contains the following configurations:
 *
 * * Database settings
 * * Secret keys
 * * Database table prefix
 * * Localized language
 * * ABSPATH
 *
 * @link https://wordpress.org/support/article/editing-wp-config-php/
 *
 * @package WordPress
 */

// ** Database settings - You can get this info from your web host ** //
/** The name of the database for WordPress */
define( 'DB_NAME', 'wordpress' );

/** Database username */
define( 'DB_USER', 'wp' );

/** Database password */
define( 'DB_PASSWORD', 'wp_pass' );

/** Database hostname */
define( 'DB_HOST', 'db:3306' );

/** Database charset to use in creating database tables. */
define( 'DB_CHARSET', 'utf8' );

/** The database collate type. Don't change this if in doubt. */
define( 'DB_COLLATE', '' );

/**#@+
 * Authentication unique keys and salts.
 *
 * Change these to different unique phrases! You can generate these using
 * the {@link https://api.wordpress.org/secret-key/1.1/salt/ WordPress.org secret-key service}.
 *
 * You can change these at any point in time to invalidate all existing cookies.
 * This will force all users to have to log in again.
 *
 * @since 2.6.0
 */
define( 'AUTH_KEY',          'T#xL}f%oGkj]gB{Z?|4s=/kI*jvxh|$9g,QwX{}<;_0*nh1k+!`0k2{k3SR0~7{O' );
define( 'SECURE_AUTH_KEY',   'wDf84H<;#5i/IzT-?Ubx!%Z(;&k#U[,N34mbG?MiI3gCDP0555>bb^jGDZXP{U^H' );
define( 'LOGGED_IN_KEY',     'E;2P;6HU*NXv!7]@#b.H$;lXB~if?z!U<D})T>:$]?Gs&:!a?H3uF2%tJwi:ZPNA' );
define( 'NONCE_KEY',         'lIs21|#[+.~e0l$^GRyFb!]x82~=DIFz%^x^o>$}Q>)CP/RM@mb2_x:4aHn-T@>F' );
define( 'AUTH_SALT',         '5Mz3jPgQeymUGE,p#i!cA-]m*Y*PTV-RB!%d+QC~4;0^u?xF.Wf<wbX2Zn7b_vdt' );
define( 'SECURE_AUTH_SALT',  '$L9</h%g3%2$jS(1 Qt|:|MT~/|n2_omw*15~G%[5]5X[|qN~rTITUq`P.p;1 :/' );
define( 'LOGGED_IN_SALT',    'MwIeOs_1`tk9%gF$mC+:ssf#|&/PH}#f6b!Ug+B=K4$o^dY_3dXUxW4w&/RU<LMQ' );
define( 'NONCE_SALT',        'a+ZED0;esR%=M TQt9~831NXa?Ym +P22=l;+Vp!>.pT2U}qU5(:shRs70eq:rSo' );
define( 'WP_CACHE_KEY_SALT', 'Lr/BtT1h%3|U-{Aj+6*2M2?$B:X/|7D[]9=PE^=|$|$9-mmmDSrf=jLQw=LPl_NA' );


/**#@-*/

/**
 * WordPress database table prefix.
 *
 * You can have multiple installations in one database if you give each
 * a unique prefix. Only numbers, letters, and underscores please!
 */
$table_prefix = 'wp_';


/* Add any custom values between this line and the "stop editing" line. */



/**
 * For developers: WordPress debugging mode.
 *
 * Change this to true to enable the display of notices during development.
 * It is strongly recommended that plugin and theme developers use WP_DEBUG
 * in their development environments.
 *
 * For information on other constants that can be used for debugging,
 * visit the documentation.
 *
 * @link https://wordpress.org/support/article/debugging-in-wordpress/
 */
if ( ! defined( 'WP_DEBUG' ) ) {
	define( 'WP_DEBUG', false );
}

/* That's all, stop editing! Happy publishing. */

/** Absolute path to the WordPress directory. */
if ( ! defined( 'ABSPATH' ) ) {
	define( 'ABSPATH', __DIR__ . '/' );
}

/** Sets up WordPress vars and included files. */
require_once ABSPATH . 'wp-settings.php';

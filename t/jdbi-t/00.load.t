use DBIx::Class::JDBICompat;
use Test::More tests => 13;

BEGIN { use_ok("Jifty::DBI::Collection"); }
BEGIN { use_ok("Jifty::DBI::Handle"); }
BEGIN { 
TODO:{ local $TODO = 'Sybase support not implemented';

use_ok("Jifty::DBI::Handle::Informix"); }
}
BEGIN { use_ok("Jifty::DBI::Handle::mysql"); }
BEGIN {
TODO: { local $TODO = 'Sybase support not implemented';
use_ok("Jifty::DBI::Handle::mysqlPP"); };
}
BEGIN {
TODO: { local $TODO = 'Sybase support not implemented';
use_ok("Jifty::DBI::Handle::ODBC"); }
};
BEGIN {
    SKIP: {
        skip "DBD::Oracle is not installed", 1
          unless eval { require DBD::Oracle };
        use_ok("Jifty::DBI::Handle::Oracle");
    }
}
BEGIN { use_ok("Jifty::DBI::Handle::Pg"); }
BEGIN { 

TODO: { local $TODO = 'Sybase support not implemented';
use_ok("Jifty::DBI::Handle::Sybase"); 
};
}
BEGIN { use_ok("Jifty::DBI::Handle::SQLite"); }
BEGIN { use_ok("Jifty::DBI::Record"); }
BEGIN { use_ok("Jifty::DBI::Record::Cachable"); }

# Commented out until ruslan sends code.
BEGIN {
    SKIP: {
        skip "Cache::Memcached is not installed", 1
          unless eval { require Cache::Memcached };
        use_ok("Jifty::DBI::Record::Memcached");
    }
}

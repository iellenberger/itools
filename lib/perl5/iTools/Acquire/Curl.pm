package iTools::Acquire::Curl;
use base qw( iTools::Acquire::Base );
$VERSION = "0.01";

use Data::Dumper; $Data::Dumper::Indent=1; $Data::Dumper::Sortkeys=1; # for debugging

use strict;
use warnings;

# === Required Method Overrides =============================================
sub fetch {
	my ($self, $uri) = @_;
	$uri = $self->uri unless defined $uri;

	# --- fetch URI content ---
	my $path = $uri->uri;
	$self->content(`curl --silent --fail $path`);

	# --- if we got an error, log it and return undef ---
	if ($?) {
		my $error = $? >> 8;
		$self->message("curl returned error $error: ". curlerror($error));
		return undef;
	}

	# --- return content ---
	return $self->content;
}

# === curl Error Messages ===================================================
our %CURLERROR = (
	1  => "Unsupported protocol",
	2  => "Failed to initialize",
	3  => "URL malformat",
	4  => "URL user malformatted. The user-part of the URL syntax was not correct",
	5  => "Couldn't resolve proxy host",
	6  => "Couldn't resolve host",
	7  => "Failed to connect to host",
	8  => "FTP weird server reply. The server sent data curl couldn't parse",
	9  => "FTP access denied. The server denied login or denied access to the particular resource or directory you wanted to reach. Most often you tried to change to a directory that doesn't exist on the server",
	10 => "FTP user/password incorrect. Either one or both were not accepted by the server",
	11 => "FTP weird PASS reply. Curl couldn't parse the reply sent to the PASS request",
	12 => "FTP weird USER reply. Curl couldn't parse the reply sent to the USER request",
	13 => "FTP weird PASV reply, Curl couldn't parse the reply sent to the PASV request",
	14 => "FTP weird 227 format. Curl couldn't parse the 227-line the server sent",
	15 => "FTP can't get host. Couldn't resolve the host IP we got in the 227-line",
	16 => "FTP can't reconnect. Couldn't connect to the host we got in the 227-line",
	17 => "FTP couldn't set binary. Couldn't change transfer method to binary",
	18 => "Partial file. Only a part of the file was transferred",
	19 => "FTP couldn't download/access the given file, the RETR (or similar) command failed",
	20 => "FTP write error. The transfer was reported bad by the server",
	21 => "FTP quote error. A quote command returned error from the server",
	22 => "HTTP page not retrieved. The requested url was found or returned another error with the HTTP error code being 400 or above",
	23 => "Write error. Curl couldn't write data to a local filesystem or similar",
	24 => "Malformed user. User name badly specified",
	25 => "FTP couldn't STOR file. The server denied the STOR operation, used for FTP uploading",
	26 => "Read error. Various reading problems",
	27 => "Out of memory. A memory allocation request failed",
	28 => "Operation timeout. The specified time-out period was reached according to the conditions",
	29 => "FTP couldn't set ASCII. The server returned an unknown reply",
	30 => "FTP PORT failed. The PORT command failed. Not all FTP servers support the PORT command, try doing a transfer using PASV instead!",
	31 => "FTP couldn't use REST. The REST command failed. This command is used for resumed FTP transfers",
	32 => "FTP couldn't use SIZE. The SIZE command failed. The command is an extension to the original FTP spec RFC 959",
	33 => "HTTP range error. The range 'command' didn't work",
	34 => "HTTP post error. Internal post-request generation error",
	35 => "SSL connect error. The SSL handshaking failed",
	36 => "FTP bad download resume. Couldn't continue an earlier aborted download",
	37 => "FILE couldn't read file. Failed to open the file. Permissions?",
	38 => "LDAP cannot bind. LDAP bind operation failed",
	39 => "LDAP search failed",
	40 => "Library not found. The LDAP library was not found",
	41 => "Function not found. A required LDAP function was not found",
	42 => "Aborted by callback. An application told curl to abort the operation",
	43 => "Internal error. A function was called with a bad parameter",
	44 => "Internal error. A function was called in a bad order",
	45 => "Interface error. A specified outgoing interface could not be used",
	46 => "Bad password entered. An error was signalled when the password was entered",
	47 => "Too many redirects. When following redirects, curl hit the maximum amount",
	48 => "Unknown TELNET option specified",
	49 => "Malformed telnet option",
	51 => "The remote peer's SSL certificate wasn't ok",
	52 => "The server didn't reply anything, which here is considered an error",
	53 => "SSL crypto engine not found",
	54 => "Cannot set SSL crypto engine as default",
	55 => "Failed sending network data",
	56 => "Failure in receiving network data",
	57 => "Share is in use (internal error)",
	58 => "Problem with the local certificate",
	59 => "Couldn't use specified SSL cipher",
	60 => "Problem with the CA cert (path? permission?)",
	61 => "Unrecognized transfer encoding",
	62 => "Invalid LDAP URL",
	63 => "Maximum file size exceeded",
	64 => "Requested FTP SSL level failed",
	65 => "Sending the data requires a rewind that failed",
	66 => "Failed to initialise SSL Engine",
	67 => "User, password or similar was not accepted and curl failed to login",
	68 => "File not found on TFTP server",
	69 => "Permission problem on TFTP server",
	70 => "Out of disk space on TFTP server",
	71 => "Illegal TFTP operation",
	72 => "Unknown TFTP transfer ID",
	73 => "File already exists (TFTP)",
	74 => "No such user (TFTP)",
	75 => "Character conversion failed",
	76 => "Character conversion functions required",
);

# --- return formatted curl error message based on error code ---
sub curlerror {
	my $code = shift;

	# --- unknown error ---
	return "Unknown error" unless exists $CURLERROR{$code} && defined $CURLERROR{$code};

	# --- split base error from extended message ---
	my ($error, $message) = ($CURLERROR{$code} =~ /^([^\.]+)\.*\s*(.*?)$/);
	
	# --- ar newline to end of error ---
	$error .= "\n";

	# --- format message to be no more than 79 char lines ---
	my $line = '';
	foreach my $word (split /\s+/, $message) {
		# --- line too long, add line break ---
		if (length "$line $word" > 75) {
			$error .= "   $line\n";
			$line = '';
		}
		$line .= " $word";
	}
	# --- tack remaining message to error ---
	$error .= "   $line\n" if $line;

	return $error;
}

1;

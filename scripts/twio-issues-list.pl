#!/usr/bin/env perl

use Term::ReadKey;
use LWP::UserAgent;
use XML::LibXML;

# Change this if the Jira URL changes
my $jiraBaseUrl = "https://issues.opennms.org";

my $filter = 13303; # 7 days
#my $filter = 13522; # 8 days
#my $filter = 13600; # 10 days
#my $filter = 13510; # 2 weeks

my $jiraLoginUrl = "${jiraBaseUrl}/login.jsp";
my $jiraSearchUrl = "${jiraBaseUrl}/sr/jira.issueviews:searchrequest-xml/${filter}/SearchRequest-${filter}.xml?tempMax=1000";

# Read our login credentials
my $creds = {};
print "Jira login\n----------\nUsername: ";
chomp ($creds->{os_username} = <STDIN>);
print "Password: ";
ReadMode('noecho');
chomp($creds->{os_password} = <STDIN>);
ReadMode(0);        # back to normal
 
# Construct the user-agent HTTP client
my $ua = LWP::UserAgent->new( requests_redirectable => [ "GET", "HEAD", "POST" ] );
$ua->cookie_jar( {} );
$ua->timeout(30);
 
# Do the login POST to Jira
my $response = $ua->post("${jiraLoginUrl}", $creds);
if ($response->is_success) {
  print "Logged in to Jira\n";
} else {
  die "Jira login failed: " . $response->status_line;
}

# Do the search GET to Jira
$response = $ua->get("${jiraSearchUrl}");
if (! $response->is_success) {
  die "Jira search failed: " . $response->status_line;
}

# Parse the XML document returned by the Jira search
my $dom = XML::LibXML->load_xml(string => $response->decoded_content);

# Crawl the DOM and generate the Markdown output
# * [HZN-266](http://issues.opennms.org/browse/HZN-266): Migrate discovery to Hibernate
my @issues = $dom->getElementsByTagName("item");
print <<EOH;
Resolved Issues Since Last TWiO
-------------------------------

EOH

foreach my $issue ($dom->getElementsByTagName("item")) {
	my ($key, $summary, $link) = ();
	foreach my $keyelem ($issue->getChildrenByTagName("key")) {
		 $key = $keyelem->textContent();
	}
	foreach my $linkelem ($issue->getChildrenByTagName("link")) {
		 $link = $linkelem->textContent();
	}
	foreach my $summaryelem ($issue->getChildrenByTagName("summary")) {
		$summary = $summaryelem->textContent();
	}
	print "* [${key}](${link}): ${summary}\n";
}

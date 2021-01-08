require 'octokit'

PER_PAGE = 30
ACCESS_TOKEN = nil # set access_token if rate limit expired

$output_file = File.new('result_by_files.txt', 'w')
$client = Octokit::Client.new(access_token: ACCESS_TOKEN)

def fetch_pr_files_from_commits(pr)
  page = 1
  files = []

  loop do
    commits = $client.pull_request_commits('rails/rails', pr[:number], per_page: PER_PAGE, page: page)
    files << commits.map { |commit| $client.commit('rails/rails', commit[:sha])[:files] }

    commits.length >= PER_PAGE ? page += 1 : break
  end

  files
end

def build_link(pr_number, file_name)
  file_hash = Digest::SHA256.hexdigest(file_name)

  p link = "https://github.com/rails/rails/pull/#{pr_number}/files#diff-#{file_hash}"

  $output_file << link << "\n"
end

# Check PR by number
pr = $client.pull_request('rails/rails', 41004)
commits_files = fetch_pr_files_from_commits(pr)
commits_files.flatten.group_by{ |e| e[:filename] }.each do |filename, files|
  build_link(pr[:number], filename) if files.length >= 2
end

# Check open PR`s

# page = 1

# loop do
#   prs = $client.pull_requests('rails/rails', state: 'open', per_page: PER_PAGE, page: page)
#   prs.each do |pr|
#     commits_files = fetch_pr_files_from_commits(pr)
#     commits_files.flatten.group_by{ |e| e[:filename] }.each do |filename, files|
#       build_link(pr[:number], filename) if files.length >= 2
#     end

#     p "Current rate_limit: #{$client.rate_limit}"
#   end

#   prs.length >= PER_PAGE ? page += 1 : break
# end

require 'octokit'

PER_PAGE = 30
PATCH_REGEX = /@@ -\d+,\d+ \+(\d+),(\d+) @@/i
ACCESS_TOKEN = nil # set access_token if rate limit expired

$output_file = File.new('result_by_patches.txt', 'w')
$files = []
$client = Octokit::Client.new(access_token: ACCESS_TOKEN)

def fetch_pr_commits(pr)
  page = 1

  loop do
    commits = $client.pull_request_commits('rails/rails', pr[:number], per_page: PER_PAGE, page: page)
    commits.each { |commit| fetch_commit(commit) }

    commits.length >= PER_PAGE ? page += 1 : break
  end
end

def fetch_pr_files(pr)
  page = 1
  pr_files = []

  loop do
    pr_files_by_page = $client.pull_request_files('rails/rails', pr[:number], per_page: PER_PAGE, page: page)
    pr_files << pr_files_by_page

    pr_files_by_page.length >= PER_PAGE ? page += 1 : break
  end

  pr_files.flatten
end

def fetch_commit(commit)
  $files << $client.commit('rails/rails', commit[:sha])[:files]
end

def find_files(pr)
  pr_files = fetch_pr_files(pr)
  grouped_files = $files.flatten.group_by{|e| e[:filename]}

  pr_files.each do |pr_file|
    filename = pr_file[:filename]
    commits_by_file = grouped_files[filename]

    next if commits_by_file.count <= 0

    commits_changed_rows_ranges = commits_by_file.map do |commit|
      commit[:patch]&.scan(PATCH_REGEX).map  { |patch| find_range(patch) }
    end

    pr_changed_rows_ranges = pr_file[:patch].scan(PATCH_REGEX).map { |patch| find_range(patch) }

    find_overlaps(pr, filename, pr_changed_rows_ranges, commits_changed_rows_ranges.flatten)
  end
end

def find_range(patch)
  from = patch[0].to_i
  to = from + patch[1].to_i - 1

  from..to
end

def find_overlaps(pr, filename, pr_changed_rows_ranges, commits_changed_rows_ranges)
  pr_changed_rows_ranges.each do |pr_changed_rows_range|
    counter = 0

    commits_changed_rows_ranges.each do |changed_rows_range|
      counter += 1 if overlaps?(pr_changed_rows_range, changed_rows_range)

      break if counter >= 2
    end

    if counter >= 2
      build_link(pr[:number], filename, pr_changed_rows_range.first, pr_changed_rows_range.last)
    end
  end
end

def overlaps?(range_1, range_2)
  range_1.cover?(range_2.first) || range_2.cover?(range_1.first)
end

def build_link(pr_number, file_name, line_from, line_to)
  file_hash = Digest::SHA256.hexdigest(file_name)

  p link =  "https://github.com/rails/rails/pull/#{pr_number}/files#diff-#{file_hash}R#{line_from}-R#{line_to}"

  $output_file << link << "\n"
end

# Check PR by number
pr = $client.pull_request('rails/rails', 41004)
fetch_pr_commits(pr)
find_files(pr)

# Check open PR`s

# page = 1

# loop do
#   prs = $client.pull_requests('rails/rails', state: 'open', per_page: PER_PAGE, page: page)
#   prs.each do |pr|
#     fetch_pr_commits(pr)
#     find_files(pr)

#     $files = []

#     p "Current rate_limit: #{$client.rate_limit}"
#   end

#   prs.length >= PER_PAGE ? page += 1 : break
# end

<div>
    <p><a href="https://github.com/philiprbrenan/GitHubCrud"><img src="https://github.com/philiprbrenan/GitHubCrud/workflows/Test/badge.svg"></a>
</div>

# Name

GitHub::Crud - Create, Read, Update, Delete files, commits, issues, and web hooks on GitHub.

# Synopsis

Create, Read, Update, Delete files, commits, issues, and web hooks on GitHub as
described at:

    https://developer.github.com/v3/repos/contents/#update-a-file

## Upload a file from an action

Upload a file created during a github action to the repository for that action:

    GITHUB_TOKEN=${{ secrets.GITHUB_TOKEN }} \
    perl -M"GitHub::Crud" -e"GitHub::Crud::writeFileFromFileFromCurrentRun q(output.txt);"

## Upload a folder

Commit a folder to GitHub then read and check some of the uploaded content:

    use GitHub::Crud;
    use Data::Table::Text qw(:all);

    my $f  = temporaryFolder;                                                     # Folder in which we will create some files to upload in the commit
    my $c  = dateTimeStamp;                                                       # Create some content
    my $if = q(/home/phil/.face);                                                 # Image file

    writeFile(fpe($f, q(data), $_, qw(txt)), $c) for 1..3;                        # Place content in files in a sub folder
    copyBinaryFile $if, my $If = fpe $f, qw(face jpg);                            # Add an image

    my $g = GitHub::Crud::new                                                     # Create GitHub
      (userid           => q(philiprbrenan),
       repository       => q(aaa),
       branch           => q(test),
       confessOnFailure => 1);

    $g->loadPersonalAccessToken;                                                  # Load a personal access token
    $g->writeCommit($f);                                                          # Upload commit - confess to any errors

    my $C = $g->read(q(data/1.txt));                                              # Read data written in commit
    my $I = $g->read(q(face.jpg));
    my $i = readBinaryFile $if;

    confess "Date stamp failed" unless $C eq $c;                                  # Check text
    confess "Image failed"      unless $i eq $I;                                  # Check image
    confess "Write commit succeeded";

## Prerequisites

Please install **curl** if it is not already present on your computer.

    sudo apt-get install curl

## Personal Access Token

You will need to create a personal access token if you wish to gain write
access to your respositories : [https://github.com/settings/tokens](https://github.com/settings/tokens).
Depending on your security requirements you can either install this token at
the well known location:

    /etc/GitHubCrudPersonalAccessToken/<github userid>

or at a location of your choice.  If you use a well known location then the
personal access token will be loaded automatically for you, else you will need
to supply it to each call via the ["personalAccessToken"](#personalaccesstoken) attribute.

The following code will install a personal access token for github userid
**uuuuuu**  in the default location:

    use GitHub::Crud qw(:all);

    my $g = GitHub::Crud::gitHub
     (userid                    => q(uuuuuu),
      personalAccessToken       => q(........................................),
     );

    $g->savePersonalAccessToken;

# Description

Create, Read, Update, Delete files, commits, issues, and web hooks on GitHub.

Version 20240408.

The following sections describe the methods in each functional area of this
module.  For an alphabetic listing of all methods by name see [Index](#index).

# Constructor

Create a [GitHub](https://github.com/philiprbrenan) object with the specified attributes describing the interface with [GitHub](https://github.com/philiprbrenan).

## new (%attributes)

Create a new [GitHub](https://github.com/philiprbrenan) object with attributes as described at: ["GitHub::Crud Definition"](#github-crud-definition).

       Parameter    Description
    1  %attributes  Attribute values

**Example:**

      my $f  = temporaryFolder;                                                     # Folder in which we will create some files to upload in the commit
      my $c  = dateTimeStamp;                                                       # Create some content
      my $if = q(/home/phil/.face);                                                 # Image file
    
      writeFile(fpe($f, q(data), $_, qw(txt)), $c) for 1..3;                        # Place content in files in a sub folder
      copyBinaryFile $if, my $If = fpe $f, qw(face jpg);                            # Add an image
    
    
      my $g = GitHub::Crud::new                                                     # Create GitHub  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

        (userid           => q(philiprbrenan),
         repository       => q(aaa),
         branch           => q(test),
         confessOnFailure => 1);
    
      $g->loadPersonalAccessToken;                                                  # Load a personal access token
      $g->writeCommit($f);                                                          # Upload commit - confess to any errors
    
      my $C = $g->read(q(data/1.txt));                                              # Read data written in commit
      my $I = $g->read(q(face.jpg));
      my $i = readBinaryFile $if;
    
      confess "Date stamp failed" unless $C eq $c;                                  # Check text
      confess "Image failed"      unless $i eq $I;                                  # Check image
      success "Write commit succeeded";
    

# Files

File actions on the contents of [GitHub](https://github.com/philiprbrenan) repositories.

## list($gitHub)

List all the files contained in a [GitHub](https://github.com/philiprbrenan) repository or all the files below a specified folder in the repository.

Required attributes: [userid](#userid), [repository](#repository).

Optional attributes: [gitFolder](#gitfolder), [refOrBranch](#reforbranch), [nonRecursive](#nonrecursive), [patKey](#patkey).

Use the [gitFolder](#gitfolder) parameter to specify the folder to start the list from, by default, the listing will start at the root folder of your repository.

Use the [nonRecursive](#nonrecursive) option if you require only the files in the start folder as otherwise all the folders in the start folder will be listed as well which might take some time.

If the list operation is successful, [failed](#failed) is set to false and [fileList](#filelist) is set to refer to an array of the file names found.

If the list operation fails then [failed](#failed) is set to true and [fileList](#filelist) is set to refer to an empty array.

Returns the list of file names found or empty list if no files were found.

       Parameter  Description
    1  $gitHub    GitHub

**Example:**

      success "list:", gitHub->list;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    
    # list: alpha.data .github/workflows/test.yaml images/aaa.txt images/aaa/bbb.txt  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    

## read($gitHub, $File)

Read data from a file on [GitHub](https://github.com/philiprbrenan).

Required attributes: [userid](#userid), [repository](#repository).

Optional attributes: [gitFile](#gitfile) = the file to read, [refOrBranch](#reforbranch), [patKey](#patkey).

If the read operation is successful, [failed](#failed) is set to false and [readData](#readdata) is set to the data read from the file.

If the read operation fails then [failed](#failed) is set to true and [readData](#readdata) is set to **undef**.

Returns the data read or **undef** if no file was found.

       Parameter  Description
    1  $gitHub    GitHub
    2  $File      File to read if not specified in gitFile

**Example:**

      my $g = gitHub;
      $g->gitFile = my $f = q(z'2  'z"z.data);
      my $d = q(𝝰𝝱𝝲);
      $g->write($d);
    
      confess "read FAILED" unless $g->read eq $d;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      success "Read passed";
    

## write   ($gitHub, $data, $File)

Write the specified data into a file on [GitHub](https://github.com/philiprbrenan).

Required attributes: [userid](#userid), [repository](#repository), [patKey](#patkey). Either specify the target file on: [GitHub](https://github.com/philiprbrenan) using the [gitFile](#gitfile) attribute or supply it as the third parameter.  Returns **true** on success else [undef](https://perldoc.perl.org/functions/undef.html).

       Parameter  Description
    1  $gitHub    GitHub object
    2  $data      Data to be written
    3  $File      Optionally the name of the file on github

**Example:**

      my $g = gitHub;
      $g->gitFile = "zzz.data";
    
      my $d = dateTimeStamp.q( 𝝰𝝱𝝲);
    
      if (1)
       {my $t = time();
    
        $g->write($d);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    
        lll "First write time: ", time() -  $t;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

       }
    
      my $r = $g->read;
      lll "Write bbb: $r";
      if (1)
       {my $t = time();
    
        $g->write($d);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    
        lll "Second write time: ", time() -  $t;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

       }
    
      confess "write FAILED" unless $g->exists;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      success "Write passed";
    

## readBlob($gitHub, $sha)

Read a [blob](https://en.wikipedia.org/wiki/Binary_large_object) from [GitHub](https://github.com/philiprbrenan).

Required attributes: [userid](#userid), [repository](#repository), [patKey](#patkey). Returns the content of the [blob](https://en.wikipedia.org/wiki/Binary_large_object) identified by the specified [SHA](https://en.wikipedia.org/wiki/SHA-1).

       Parameter  Description
    1  $gitHub    GitHub object
    2  $sha       Data to be written

**Example:**

      my $g = gitHub;
      $g->gitFile = "face.jpg";
      my $d = readBinaryFile(q(/home/phil/.face));
      my $s = $g->writeBlob($d);
      my $S = q(4a2df549febb701ba651aae46e041923e9550cb8);
      confess q(Write blob FAILED) unless $s eq $S;
    
    
      my $D = $g->readBlob($s);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      confess q(Write/Read blob FAILED) unless $d eq $D;
      success q(Write/Read blob passed);
    

## writeBlob   ($gitHub, $data)

Write data into a [GitHub](https://github.com/philiprbrenan) as a [blob](https://en.wikipedia.org/wiki/Binary_large_object) that can be referenced by future commits.

Required attributes: [userid](#userid), [repository](#repository), [patKey](#patkey). Returns the [SHA](https://en.wikipedia.org/wiki/SHA-1) of the created [blob](https://en.wikipedia.org/wiki/Binary_large_object) or [undef](https://perldoc.perl.org/functions/undef.html) in a failure occurred.

       Parameter  Description
    1  $gitHub    GitHub object
    2  $data      Data to be written

**Example:**

      my $g = gitHub;
      $g->gitFile = "face.jpg";
      my $d = readBinaryFile(q(/home/phil/.face));
    
      my $s = $g->writeBlob($d);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      my $S = q(4a2df549febb701ba651aae46e041923e9550cb8);
      confess q(Write blob FAILED) unless $s eq $S;
    
      my $D = $g->readBlob($s);
      confess q(Write/Read blob FAILED) unless $d eq $D;
      success q(Write/Read blob passed);
    

## copy($gitHub, $target)

Copy a source file from one location to another target location in your [GitHub](https://github.com/philiprbrenan) repository, overwriting the target file if it already exists.

Required attributes: [userid](#userid), [repository](#repository), [patKey](#patkey), [gitFile](#gitfile) = the file to be copied.

Optional attributes: [refOrBranch](#reforbranch).

If the write operation is successful, [failed](#failed) is set to false otherwise it is set to true.

Returns **updated** if the write updated the file, **created** if the write created the file else **undef** if the write failed.

       Parameter  Description
    1  $gitHub    GitHub object
    2  $target    The name of the file to be created

**Example:**

      my ($f1, $f2) = ("zzz.data", "zzz2.data");
      my $g = gitHub;
      $g->gitFile   = $f2; $g->delete;
      $g->gitFile   = $f1;
      my $d = dateTimeStamp;
      my $w = $g->write($d);
    
      my $r = $g->copy($f2);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      lll "Copy created: $r";
      $g->gitFile   = $f2;
      my $D = $g->read;
      lll "Read     ccc: $D";
    
      confess "copy FAILED" unless $d eq $D;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      success "Copy passed"
    

## exists  ($gitHub)

Test whether a file exists on [GitHub](https://github.com/philiprbrenan) or not and returns an object including the **sha** and **size** fields if it does else [undef](https://perldoc.perl.org/functions/undef.html).

Required attributes: [userid](#userid), [repository](#repository), [gitFile](#gitfile) file to test.

Optional attributes: [refOrBranch](#reforbranch), [patKey](#patkey).

       Parameter  Description
    1  $gitHub    GitHub object

**Example:**

      my $g = gitHub;
      $g->gitFile    = "test4.html";
      my $d = dateTimeStamp;
      $g->write($d);
    
      confess "exists FAILED" unless $g->read eq $d;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      $g->delete;
    
      confess "exists FAILED" if $g->read eq $d;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      success "Exists passed";
    

## rename  ($gitHub, $target)

Rename a source file on [GitHub](https://github.com/philiprbrenan) if the target file name is not already in use.

Required attributes: [userid](#userid), [repository](#repository), [patKey](#patkey), [gitFile](#gitfile) = the file to be renamed.

Optional attributes: [refOrBranch](#reforbranch).

Returns the new name of the file **renamed** if the rename was successful else **undef** if the rename failed.

       Parameter  Description
    1  $gitHub    GitHub object
    2  $target    The new name of the file

**Example:**

      my ($f1, $f2) = qw(zzz.data zzz2.data);
      my $g = gitHub;
         $g->gitFile = $f2; $g->delete;
    
      my $d = dateTimeStamp;
      $g->gitFile  = $f1;
      $g->write($d);
    
      confess "rename FAILED" unless $g->read eq $d;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    
    
      $g->rename($f2);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    
      confess "rename FAILED" if $g->exists;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    
      $g->gitFile  = $f2;
    
      confess "rename FAILED" if $g->read eq $d;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      success "Rename passed";
    

## delete  ($gitHub)

Delete a file from [GitHub](https://github.com/philiprbrenan).

Required attributes: [userid](#userid), [repository](#repository), [patKey](#patkey), [gitFile](#gitfile) = the file to be deleted.

Optional attributes: [refOrBranch](#reforbranch).

If the delete operation is successful, [failed](#failed) is set to false otherwise it is set to true.

Returns true if the delete was successful else false.

       Parameter  Description
    1  $gitHub    GitHub object

**Example:**

      my $g = gitHub;
      my $d = dateTimeStamp;
      $g->gitFile = "zzz.data";
      $g->write($d);
    
    
      confess "delete FAILED" unless $g->read eq $d;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    
      if (1)
       {my $t = time();
    
        my $d = $g->delete;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

        lll "Delete   1: ", $d;
    
        lll "First delete: ", time() -  $t;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    
        confess "delete FAILED" if $g->exists;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

       }
    
      if (1)
       {my $t = time();
    
        my $d = $g->delete;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

        lll "Delete   1: ", $d;
    
        lll "Second delete: ", time() -  $t;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    
        confess "delete FAILED" if $g->exists;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

       }
      success "Delete passed";
    

# Repositories

Perform actions on [GitHub](https://github.com/philiprbrenan) repositories.

## getRepository   ($gitHub)

Get the overall details of a repository

       Parameter  Description
    1  $gitHub    GitHub object

**Example:**

      my $r = gitHub(repository => q(C))->getRepository;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      success "Get repository succeeded";
    

## listCommits ($gitHub)

List all the commits in a [GitHub](https://github.com/philiprbrenan) repository.

Required attributes: [userid](#userid), [repository](#repository).

       Parameter  Description
    1  $gitHub    GitHub object

**Example:**

      my $c = gitHub->listCommits;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      my %s = listCommitShas $c;
      lll "Commits
  ",     dump $c;
      lll "Commit shas
  ", dump \%s;
      success "ListCommits passed";
    

## listCommitShas  ($commits)

Create {commit name => sha} from the results of ["listCommits"](#listcommits).

       Parameter  Description
    1  $commits   Commits from L</listCommits>

**Example:**

      my $c = gitHub->listCommits;
    
      my %s = listCommitShas $c;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      lll "Commits
  ",     dump $c;
      lll "Commit shas
  ", dump \%s;
      success "ListCommits passed";
    

## writeCommit ($gitHub, $folder, @files)

Write all the files in a **$folder** (or just the the named files) into a [GitHub](https://github.com/philiprbrenan) repository in parallel as a commit on the specified branch.

Required attributes: [userid](#userid), [repository](#repository), [refOrBranch](#reforbranch).

       Parameter  Description
    1  $gitHub    GitHub object
    2  $folder    File prefix to remove
    3  @files     Files to write

**Example:**

      my $f  = temporaryFolder;                                                     # Folder in which we will create some files to upload in the commit
      my $c  = dateTimeStamp;                                                       # Create some content
      my $if = q(/home/phil/.face);                                                 # Image file
    
      writeFile(fpe($f, q(data), $_, qw(txt)), $c) for 1..3;                        # Place content in files in a sub folder
      copyBinaryFile $if, my $If = fpe $f, qw(face jpg);                            # Add an image
    
      my $g = GitHub::Crud::new                                                     # Create GitHub
        (userid           => q(philiprbrenan),
         repository       => q(aaa),
         branch           => q(test),
         confessOnFailure => 1);
    
      $g->loadPersonalAccessToken;                                                  # Load a personal access token
    
      $g->writeCommit($f);                                                          # Upload commit - confess to any errors  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    
      my $C = $g->read(q(data/1.txt));                                              # Read data written in commit
      my $I = $g->read(q(face.jpg));
      my $i = readBinaryFile $if;
    
      confess "Date stamp failed" unless $C eq $c;                                  # Check text
      confess "Image failed"      unless $i eq $I;                                  # Check image
      success "Write commit succeeded";
    

## listWebHooks($gitHub)

List web hooks associated with your [GitHub](https://github.com/philiprbrenan) repository.

Required: [userid](#userid), [repository](#repository), [patKey](#patkey). 

If the list operation is successful, [failed](#failed) is set to false otherwise it is set to true.

Returns true if the list  operation was successful else false.

       Parameter  Description
    1  $gitHub    GitHub object

**Example:**

      success join ' ', q(Webhooks:), dump(gitHub->listWebHooks);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    

## createPushWebHook   ($gitHub)

Create a web hook for your [GitHub](https://github.com/philiprbrenan) userid.

Required: [userid](#userid), [repository](#repository), [url](#url), [patKey](#patkey).

Optional: [secret](#secret).

If the create operation is successful, [failed](#failed) is set to false otherwise it is set to true.

Returns true if the web hook was created successfully else false.

       Parameter  Description
    1  $gitHub    GitHub object

**Example:**

      my $g = gitHub;
    
      my $d = $g->createPushWebHook;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      success join ' ', "Create web hook:", dump($d);
    

## listRepositories($gitHub)

List the repositories accessible to a user on [GitHub](https://github.com/philiprbrenan).

Required: [userid](#userid).

Returns details of the repositories.

       Parameter  Description
    1  $gitHub    GitHub object

**Example:**

      success "List repositories: ", dump(gitHub()->listRepositories);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    

## createRepository($gitHub)

Create a repository on [GitHub](https://github.com/philiprbrenan).

Required: [userid](#userid), [repository](#repository).

Returns true if the issue was created successfully else false.

       Parameter  Description
    1  $gitHub    GitHub object

**Example:**

      gitHub(repository => q(ccc))->createRepository;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      success "Create repository succeeded";
    

## createRepositoryFromSavedToken  ($userid, $repository, $private, $accessFolderOrToken)

Create a repository on [GitHub](https://github.com/philiprbrenan) using an access token either as supplied or saved in a file using [savePersonalAccessToken](#savepersonalaccesstoken).

Returns true if the issue was created successfully else false.

       Parameter             Description
    1  $userid               Userid on GitHub
    2  $repository           The repository name
    3  $private              True if the repo is private
    4  $accessFolderOrToken  Location of access token.

**Example:**

      createRepositoryFromSavedToken(q(philiprbrenan), q(ddd));  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      success "Create repository succeeded";
    

# Issues

Create issues on [GitHub](https://github.com/philiprbrenan).

## createIssue ($gitHub)

Create an issue on [GitHub](https://github.com/philiprbrenan).

Required: [userid](#userid), [repository](#repository), [body](#body), [title](#title).

If the operation is successful, [failed](#failed) is set to false otherwise it is set to true.

Returns true if the issue was created successfully else false.

       Parameter  Description
    1  $gitHub    GitHub object

**Example:**

      gitHub(title=>q(Hello), body=>q(World))->createIssue;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      success "Create issue succeeded";
    

# Using saved access tokens

Call methods directly using a saved access token rather than first creating a [GitHub](https://github.com/philiprbrenan) description object and then calling methods using it. This is often more convenient if you just want to perform one or two actions using a [Perl](http://www.perl.org/) one liner. See: [https://github.com/philiprbrenan/GitHubCrud/blob/main/.github/workflows/main.yml](https://github.com/philiprbrenan/GitHubCrud/blob/main/.github/workflows/main.yml) for examples in action.

## createIssueFromSavedToken   ($userid, $repository, $title, $body, $accessFolderOrToken)

Create an issue on [GitHub](https://github.com/philiprbrenan) using an access token as supplied or saved in a file using [savePersonalAccessToken](#savepersonalaccesstoken).

Returns true if the issue was created successfully else false.

       Parameter             Description
    1  $userid               Userid on GitHub
    2  $repository           Repository name
    3  $title                Issue title
    4  $body                 Issue body
    5  $accessFolderOrToken  Location of access token.

**Example:**

      &createIssueFromSavedToken(qw(philiprbrenan ddd hello World));  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      success "Create issue succeeded";
    

## writeFileUsingSavedToken($userid, $repository, $file, $content, $accessFolderOrToken)

Write to a file on [GitHub](https://github.com/philiprbrenan) using a personal access token as supplied or saved in a file. Return **1** on success or confess to any failure.

       Parameter             Description
    1  $userid               Userid on GitHub
    2  $repository           Repository name
    3  $file                 File name on github
    4  $content              File content
    5  $accessFolderOrToken  Location of access token.

**Example:**

      my $s = q(HelloWorld);
    
      &writeFileUsingSavedToken(qw(philiprbrenan ddd hello.txt), $s);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      my $S = gitHub(repository=>q(ddd), gitFile=>q(hello.txt))->read;
    
      confess "Write file using saved token FAILED" unless $s eq $S;
      success "Write file using saved token succeeded";
    

## writeFileFromFileUsingSavedToken($userid, $repository, $file, $localFile, $accessFolderOrToken)

Copy a file to [GitHub](https://github.com/philiprbrenan)  using a personal access token as supplied or saved in a file. Return **1** on success or confess to any failure.

       Parameter             Description
    1  $userid               Userid on GitHub
    2  $repository           Repository name
    3  $file                 File name on github
    4  $localFile            File content
    5  $accessFolderOrToken  Location of access token.

**Example:**

      my $f = writeFile(undef, my $s = "World
  ");
    
      &writeFileFromFileUsingSavedToken(qw(philiprbrenan ddd hello.txt), $f);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      my $S = gitHub(repository=>q(ddd), gitFile=>q(hello.txt))->read;
      confess "Write file from file using saved token FAILED" unless $s eq $S;
      success "Write file from file using saved token succeeded"
    

## readFileUsingSavedToken ($userid, $repository, $file, $accessFolderOrToken)

Read from a file on [GitHub](https://github.com/philiprbrenan) using a personal access token as supplied or saved in a file.  Return the content of the file on success or confess to any failure.

       Parameter             Description
    1  $userid               Userid on GitHub
    2  $repository           Repository name
    3  $file                 File name on GitHub
    4  $accessFolderOrToken  Location of access token.

**Example:**

      my $s = q(Hello to the World);
              &writeFileUsingSavedToken(qw(philiprbrenan ddd hello.txt), $s);
    
      my $S = &readFileUsingSavedToken (qw(philiprbrenan ddd hello.txt));  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    
      confess "Read file using saved token FAILED" unless $s eq $S;
      success "Read file using saved token succeeded"
    

## writeFolderUsingSavedToken  ($userid, $repository, $targetFolder, $localFolder, $accessFolderOrToken)

Write all the files in a local folder to a target folder on a named [GitHub](https://github.com/philiprbrenan) repository using a personal access token as supplied or saved in a file.

       Parameter             Description
    1  $userid               Userid on GitHub
    2  $repository           Repository name
    3  $targetFolder         Target folder on GitHub
    4  $localFolder          Local folder name
    5  $accessFolderOrToken  Location of access token.

**Example:**

      writeCommitUsingSavedToken("philiprbrenan", "test", "/home/phil/files/");
    
      writeFolderUsingSavedToken("philiprbrenan", "test", "files", "/home/phil/files/");  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    

## writeCommitUsingSavedToken  ($userid, $repository, $source, $accessFolderOrToken)

Write all the files in a local folder to a named [GitHub](https://github.com/philiprbrenan) repository using a personal access token as supplied or saved in a file.

       Parameter             Description
    1  $userid               Userid on GitHub
    2  $repository           Repository name
    3  $source               Local folder on GitHub
    4  $accessFolderOrToken  Optionally: location of access token.

**Example:**

      writeCommitUsingSavedToken("philiprbrenan", "test", "/home/phil/files/");  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      writeFolderUsingSavedToken("philiprbrenan", "test", "files", "/home/phil/files/");
    

## deleteFileUsingSavedToken   ($userid, $repository, $target, $accessFolderOrToken)

Delete a file on [GitHub](https://github.com/philiprbrenan) using a saved token

       Parameter             Description
    1  $userid               Userid on GitHub
    2  $repository           Repository name
    3  $target               File on GitHub
    4  $accessFolderOrToken  Optional: the folder containing saved access tokens.

**Example:**

      deleteFileUsingSavedToken("philiprbrenan", "test", "aaa.data");  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    

## getRepositoryUsingSavedToken($userid, $repository, $accessFolderOrToken)

Get repository details from [GitHub](https://github.com/philiprbrenan) using a saved token

       Parameter             Description
    1  $userid               Userid on GitHub
    2  $repository           Repository name
    3  $accessFolderOrToken  Optionally: location of access token.

**Example:**

      my $r = getRepositoryUsingSavedToken(q(philiprbrenan), q(aaa));  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      success "Get repository using saved access token succeeded";
    

## listRepositoryUsingSavedToken   ($userid, $repository, $accessFolderOrToken)

List the files in a repository using a saved token

       Parameter             Description
    1  $userid               Userid on GitHub
    2  $repository           Repository name
    3  $accessFolderOrToken  Optionally: location of access token.

**Example:**

      listRepositoryUsingSavedToken("philiprbrenan", "test", "/home/phil/files/");  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    

## getRepositoryUpdatedAtUsingSavedToken   ($userid, $repository, $accessFolderOrToken)

Get the last time a repository was updated via the 'updated\_at' field using a saved token and return the time in number of seconds since the Unix epoch.

       Parameter             Description
    1  $userid               Userid on GitHub
    2  $repository           Repository name
    3  $accessFolderOrToken  Optionally: location of access token.

**Example:**

      my $u = getRepositoryUpdatedAtUsingSavedToken(q(philiprbrenan), q(aaa));  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      success "Get repository updated_at field succeeded";
    

# Actions

Perform an action against the current repository while running as a [GitHub](https://github.com/philiprbrenan) action. If such an action requires a security token please supply the token as shown in at the end of: [https://github.com/philiprbrenan/maze/blob/main/.github/workflows/main.yml](https://github.com/philiprbrenan/maze/blob/main/.github/workflows/main.yml).

## createIssueInCurrentRepo($title, $body)

Create an issue in the current [GitHub](https://github.com/philiprbrenan) repository if we are running on [GitHub](https://github.com/philiprbrenan).

       Parameter  Description
    1  $title     Title of issue
    2  $body      Body of issue

**Example:**

      createIssueInCurrentRepo("Hello World", "Need to run Hello World");  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    
      writeFileFromCurrentRun("output.text", "Hello World");
      writeFileFromFileFromCurrentRun("output.txt");
      writeBinaryFileFromFileInCurrentRun("image.jpg", "out/image.jpg");
    

## writeFileFromCurrentRun ($target, $text)

Write text into a file in the current [GitHub](https://github.com/philiprbrenan) repository if we are running on [GitHub](https://github.com/philiprbrenan).

       Parameter  Description
    1  $target    The target file name in the repo
    2  $text      The text to write into this file

**Example:**

      createIssueInCurrentRepo("Hello World", "Need to run Hello World");
    
    
      writeFileFromCurrentRun("output.text", "Hello World");  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      writeFileFromFileFromCurrentRun("output.txt");
      writeBinaryFileFromFileInCurrentRun("image.jpg", "out/image.jpg");
    

## writeFileFromFileFromCurrentRun ($target)

Write to a file in the current [GitHub](https://github.com/philiprbrenan) repository by copying a local file if we are running on [GitHub](https://github.com/philiprbrenan).

       Parameter  Description
    1  $target    File name both locally and in the repo

**Example:**

      createIssueInCurrentRepo("Hello World", "Need to run Hello World");
    
      writeFileFromCurrentRun("output.text", "Hello World");
    
      writeFileFromFileFromCurrentRun("output.txt");  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      writeBinaryFileFromFileInCurrentRun("image.jpg", "out/image.jpg");
    

## writeBinaryFileFromFileInCurrentRun ($target, $source)

Write to a file in the current [GitHub](https://github.com/philiprbrenan) repository by copying a local binary file if we are running on [GitHub](https://github.com/philiprbrenan).

       Parameter  Description
    1  $target    The target file name in the repo
    2  $source    The current file name in the run

**Example:**

      createIssueInCurrentRepo("Hello World", "Need to run Hello World");
    
      writeFileFromCurrentRun("output.text", "Hello World");
      writeFileFromFileFromCurrentRun("output.txt");
    
      writeBinaryFileFromFileInCurrentRun("image.jpg", "out/image.jpg");  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    

# Access tokens

Load and save access tokens. Some [GitHub](https://github.com/philiprbrenan) requests must be signed with an [Oauth](https://en.wikipedia.org/wiki/OAuth)  access token. These methods help you store and reuse such tokens. Access tokens can be created at: [https://github.com/settings/tokens](https://github.com/settings/tokens).

## savePersonalAccessToken ($gitHub)

Save a [GitHub](https://github.com/philiprbrenan) personal access token by userid in folder [personalAccessTokenFolder](#personalaccesstokenfolder).

       Parameter  Description
    1  $gitHub    GitHub object

**Example:**

      my $d = temporaryFolder;
      my $t = join '', 1..20;
    
      my $g = gitHub
       (userid                    => q(philiprbrenan),
        personalAccessToken       => $t,
        personalAccessTokenFolder => $d,
       );
    
    
              $g->savePersonalAccessToken;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      my $T = $g->loadPersonalAccessToken;
    
      confess "Load/Save token FAILED" unless $t eq $T;
      success "Load/Save token succeeded"
    

## loadPersonalAccessToken ($gitHub)

Load a personal access token by userid from folder [personalAccessTokenFolder](#personalaccesstokenfolder).

       Parameter  Description
    1  $gitHub    GitHub object

**Example:**

      my $d = temporaryFolder;
      my $t = join '', 1..20;
    
      my $g = gitHub
       (userid                    => q(philiprbrenan),
        personalAccessToken       => $t,
        personalAccessTokenFolder => $d,
       );
    
              $g->savePersonalAccessToken;
    
      my $T = $g->loadPersonalAccessToken;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    
      confess "Load/Save token FAILED" unless $t eq $T;
      success "Load/Save token succeeded"
    

# Hash Definitions

## GitHub::Crud Definition

Attributes describing the interface with [GitHub](https://github.com/philiprbrenan).

### Input fields

#### body

The body of an issue.

#### branch

Branch name (you should create this branch first) or omit it for the default branch which is usually 'master'.

#### confessOnFailure

Confess to any failures

#### gitFile

File name on [GitHub](https://github.com/philiprbrenan) - this name can contain '/'. This is the file to be read from, written to, copied from, checked for existence or deleted.

#### gitFolder

Folder name on [GitHub](https://github.com/philiprbrenan) - this name can contain '/'.

#### message

Optional commit message

#### nonRecursive

Fetch only one level of files with [list](https://en.wikipedia.org/wiki/Linked_list).

#### personalAccessToken

A personal access token with scope "public\_repo" as generated on page: https://github.com/settings/tokens.

#### personalAccessTokenFolder

The folder into which to save personal access tokens. Set to **/etc/GitHubCrudPersonalAccessToken** by default.

#### private

Whether the repository being created should be private or not.

#### repository

The name of the repository to be worked on minus the userid - you should create this repository first manually.

#### secret

The secret for a web hook - this is created by the creator of the web hook and remembered by [GitHub](https://github.com/philiprbrenan),

#### title

The title of an issue.

#### userid

Userid on [GitHub](https://github.com/philiprbrenan) of the repository to be worked on.

#### webHookUrl

The url for a web hook.

### Output fields

#### failed

Defined if the last request to [GitHub](https://github.com/philiprbrenan) failed else **undef**.

#### fileList

Reference to an array of files produced by [list](#list).

#### readData

Data produced by [read](#read).

#### response

A reference to [GitHub](https://github.com/philiprbrenan)'s response to the latest request.

## GitHub::Crud::Response Definition

Attributes describing a response from [GitHub](https://github.com/philiprbrenan).

### Output fields

#### content

The actual content of the file from [GitHub](https://github.com/philiprbrenan).

#### data

The data received from [GitHub](https://github.com/philiprbrenan), normally in [Json](https://en.wikipedia.org/wiki/JSON) format.

#### status

Our version of Status.

# Private Methods

## currentRepo ()

Create a [GitHub](https://github.com/philiprbrenan) object for the  current repo if we are on [GitHub](https://github.com/philiprbrenan) actions

# Index

1 [copy](#copy) - Copy a source file from one location to another target location in your [GitHub](https://github.com/philiprbrenan) repository, overwriting the target file if it already exists.

2 [createIssue](#createissue) - Create an issue on [GitHub](https://github.com/philiprbrenan).

3 [createIssueFromSavedToken](#createissuefromsavedtoken) - Create an issue on [GitHub](https://github.com/philiprbrenan) using an access token as supplied or saved in a file using [savePersonalAccessToken](#savepersonalaccesstoken).

4 [createIssueInCurrentRepo](#createissueincurrentrepo) - Create an issue in the current [GitHub](https://github.com/philiprbrenan) repository if we are running on [GitHub](https://github.com/philiprbrenan).

5 [createPushWebHook](#createpushwebhook) - Create a web hook for your [GitHub](https://github.com/philiprbrenan) userid.

6 [createRepository](#createrepository) - Create a repository on [GitHub](https://github.com/philiprbrenan).

7 [createRepositoryFromSavedToken](#createrepositoryfromsavedtoken) - Create a repository on [GitHub](https://github.com/philiprbrenan) using an access token either as supplied or saved in a file using [savePersonalAccessToken](#savepersonalaccesstoken).

8 [currentRepo](#currentrepo) - Create a [GitHub](https://github.com/philiprbrenan) object for the  current repo if we are on [GitHub](https://github.com/philiprbrenan) actions

9 [delete](#delete) - Delete a file from [GitHub](https://github.com/philiprbrenan).

10 [deleteFileUsingSavedToken](#deletefileusingsavedtoken) - Delete a file on [GitHub](https://github.com/philiprbrenan) using a saved token

11 [exists](#exists) - Test whether a file exists on [GitHub](https://github.com/philiprbrenan) or not and returns an object including the **sha** and **size** fields if it does else [undef](https://perldoc.perl.org/functions/undef.html).

12 [getRepository](#getrepository) - Get the overall details of a repository

13 [getRepositoryUpdatedAtUsingSavedToken](#getrepositoryupdatedatusingsavedtoken) - Get the last time a repository was updated via the 'updated\_at' field using a saved token and return the time in number of seconds since the Unix epoch.

14 [getRepositoryUsingSavedToken](#getrepositoryusingsavedtoken) - Get repository details from [GitHub](https://github.com/philiprbrenan) using a saved token

15 [list](#list) - List all the files contained in a [GitHub](https://github.com/philiprbrenan) repository or all the files below a specified folder in the repository.

16 [listCommits](#listcommits) - List all the commits in a [GitHub](https://github.com/philiprbrenan) repository.

17 [listCommitShas](#listcommitshas) - Create {commit name => sha} from the results of ["listCommits"](#listcommits).

18 [listRepositories](#listrepositories) - List the repositories accessible to a user on [GitHub](https://github.com/philiprbrenan).

19 [listRepositoryUsingSavedToken](#listrepositoryusingsavedtoken) - List the files in a repository using a saved token

20 [listWebHooks](#listwebhooks) - List web hooks associated with your [GitHub](https://github.com/philiprbrenan) repository.

21 [loadPersonalAccessToken](#loadpersonalaccesstoken) - Load a personal access token by userid from folder [personalAccessTokenFolder](#personalaccesstokenfolder).

22 [new](#new) - Create a new [GitHub](https://github.com/philiprbrenan) object with attributes as described at: ["GitHub::Crud Definition"](#github-crud-definition).

23 [read](#read) - Read data from a file on [GitHub](https://github.com/philiprbrenan).

24 [readBlob](#readblob) - Read a [blob](https://en.wikipedia.org/wiki/Binary_large_object) from [GitHub](https://github.com/philiprbrenan).

25 [readFileUsingSavedToken](#readfileusingsavedtoken) - Read from a file on [GitHub](https://github.com/philiprbrenan) using a personal access token as supplied or saved in a file.

26 [rename](#rename) - Rename a source file on [GitHub](https://github.com/philiprbrenan) if the target file name is not already in use.

27 [savePersonalAccessToken](#savepersonalaccesstoken) - Save a [GitHub](https://github.com/philiprbrenan) personal access token by userid in folder [personalAccessTokenFolder](#personalaccesstokenfolder).

28 [write](#write) - Write the specified data into a file on [GitHub](https://github.com/philiprbrenan).

29 [writeBinaryFileFromFileInCurrentRun](#writebinaryfilefromfileincurrentrun) - Write to a file in the current [GitHub](https://github.com/philiprbrenan) repository by copying a local binary file if we are running on [GitHub](https://github.com/philiprbrenan).

30 [writeBlob](#writeblob) - Write data into a [GitHub](https://github.com/philiprbrenan) as a [blob](https://en.wikipedia.org/wiki/Binary_large_object) that can be referenced by future commits.

31 [writeCommit](#writecommit) - Write all the files in a **$folder** (or just the the named files) into a [GitHub](https://github.com/philiprbrenan) repository in parallel as a commit on the specified branch.

32 [writeCommitUsingSavedToken](#writecommitusingsavedtoken) - Write all the files in a local folder to a named [GitHub](https://github.com/philiprbrenan) repository using a personal access token as supplied or saved in a file.

33 [writeFileFromCurrentRun](#writefilefromcurrentrun) - Write text into a file in the current [GitHub](https://github.com/philiprbrenan) repository if we are running on [GitHub](https://github.com/philiprbrenan).

34 [writeFileFromFileFromCurrentRun](#writefilefromfilefromcurrentrun) - Write to a file in the current [GitHub](https://github.com/philiprbrenan) repository by copying a local file if we are running on [GitHub](https://github.com/philiprbrenan).

35 [writeFileFromFileUsingSavedToken](#writefilefromfileusingsavedtoken) - Copy a file to [GitHub](https://github.com/philiprbrenan)  using a personal access token as supplied or saved in a file.

36 [writeFileUsingSavedToken](#writefileusingsavedtoken) - Write to a file on [GitHub](https://github.com/philiprbrenan) using a personal access token as supplied or saved in a file.

37 [writeFolderUsingSavedToken](#writefolderusingsavedtoken) - Write all the files in a local folder to a target folder on a named [GitHub](https://github.com/philiprbrenan) repository using a personal access token as supplied or saved in a file.

# Installation

This module is written in 100% Pure Perl and, thus, it is easy to read,
comprehend, use, modify and install via **cpan**:

    sudo cpan install GitHub::Crud

# Author

[philiprbrenan@gmail.com](mailto:philiprbrenan@gmail.com)

[http://prb.appaapps.com](http://prb.appaapps.com)

# Copyright

Copyright (c) 2016-2023 Philip R Brenan.

This module is free software. It may be used, redistributed and/or modified
under the same terms as Perl itself.

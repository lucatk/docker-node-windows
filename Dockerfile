FROM mcr.microsoft.com/windows/servercore:ltsc2019 as download

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# PATH isn't actually set in the Docker image, so we have to set it from within the container
RUN $newPath = ('C:\nodejs;{0}\Yarn\bin;{1}' -f $env:LOCALAPPDATA, $env:PATH); \
    Write-Host ('Updating PATH: {0}' -f $newPath); \
    [Environment]::SetEnvironmentVariable('PATH', $newPath, [EnvironmentVariableTarget]::Machine)
# doing this first to share cache across versions more aggressively

ENV NODE_VERSION 18.14.2
ENV NODE_SHA256 fccac5e259f1196a2a30e82f42211dd7dddd9a48e4fd3f1627900aa23dff4ffa
ENV YARN_VERSION 1.22.19

RUN $url = ('https://nodejs.org/dist/v{0}/node-v{0}-win-x64.zip' -f $env:NODE_VERSION); \
    Write-Host ('Downloading {0} ...' -f $url); \
    Invoke-WebRequest -Uri $url -OutFile 'node.zip'; \
    \
    Write-Host ('Verifying sha256 ({0}) ...' -f $env:NODE_SHA256); \
    if ((Get-FileHash node.zip -Algorithm sha256).Hash -ne $env:NODE_SHA256) { throw 'SHA256 mismatch' }; \
    \
    Write-Host 'Expanding ...'; \
    Expand-Archive node.zip -DestinationPath C:\; \
    \
    Write-Host 'Renaming ...'; \
    Rename-Item -Path ('C:\node-v{0}-win-x64' -f $env:NODE_VERSION) -NewName 'C:\nodejs'; \
    \
    Write-Host 'Removing ...'; \
    Remove-Item node.zip -Force; \
    \
    Write-Host 'Verifying ("node --version") ...'; \
    node --version; \
    Write-Host 'Verifying ("npm --version") ...'; \
    npm --version; \
    \
    Write-Host 'Complete.'

# "It is recommended to install Yarn through the npm package manager" (https://classic.yarnpkg.com/en/docs/install)
RUN Write-Host 'Installing "yarn" ...'; \
    npm install --global ('yarn@{0}' -f $env:YARN_VERSION); \
    \
    Write-Host 'Verifying ("yarn --version") ...'; \
    yarn --version; \
    \
    Write-Host 'Complete.'

ENV GIT_VERSION 2.20.1
ENV GIT_DOWNLOAD_URL https://github.com/git-for-windows/git/releases/download/v${GIT_VERSION}.windows.1/MinGit-${GIT_VERSION}-busybox-64-bit.zip
ENV GIT_SHA256 9817ab455d9cbd0b09d8664b4afbe4bbf78d18b556b3541d09238501a749486c

RUN [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 ; \
    Invoke-WebRequest -UseBasicParsing $env:GIT_DOWNLOAD_URL -OutFile git.zip; \
    if ((Get-FileHash git.zip -Algorithm sha256).Hash -ne $env:GIT_SHA256) {exit 1} ; \
    Expand-Archive git.zip -DestinationPath C:\git; \
    Remove-Item git.zip

FROM mcr.microsoft.com/windows/nanoserver:ltsc2019

ENV NPM_CONFIG_LOGLEVEL info

COPY --from=download /nodejs /nodejs
COPY --from=download /git /git

ARG SETX=/M
USER ContainerAdministrator
RUN setx %SETX% PATH "%PATH%;C:\nodejs;C:\git\cmd;C:\git\mingw64\bin;C:\git\usr\bin"
USER ContainerUser

CMD [ "node" ]

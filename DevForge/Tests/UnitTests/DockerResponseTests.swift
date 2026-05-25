import Testing
import Foundation
@testable import DevForge

struct DockerResponseTests {
    @Test func decodeContainer() throws {
        let json = """
        {
            "Id": "abc123def456",
            "Names": ["/my-container"],
            "Image": "nginx:latest",
            "Status": "Up 5 minutes",
            "State": "running",
            "Ports": [
                {"PrivatePort": 80, "PublicPort": 8080, "Type": "tcp"}
            ],
            "Created": 1700000000
        }
        """
        let data = try #require(json.data(using: .utf8))
        let container = try JSONDecoder().decode(DockerContainer.self, from: data)

        #expect(container.id == "abc123def456")
        #expect(container.displayName == "my-container")
        #expect(container.image == "nginx:latest")
        #expect(container.state == "running")
        #expect(container.ports.count == 1)
        #expect(container.ports.first?.display == "8080->80/tcp")
    }

    @Test func decodeImage() throws {
        let json = """
        {
            "Id": "sha256:xyz789",
            "RepoTags": ["nginx:latest"],
            "Size": 140000000,
            "Created": 1700000000
        }
        """
        let data = try #require(json.data(using: .utf8))
        let image = try JSONDecoder().decode(DockerImage.self, from: data)

        #expect(image.shortId == "xyz789")
        #expect(image.displayTag == "nginx:latest")
        #expect(image.sizeFormatted == "133.5 MB")
    }

    @Test func decodeContainerDetail() throws {
        let json = """
        {
            "Id": "abc123",
            "Name": "/my-container",
            "State": {
                "Status": "running",
                "Running": true,
                "StartedAt": "2025-01-01T00:00:00Z",
                "FinishedAt": "0001-01-01T00:00:00Z"
            },
            "Config": {
                "Image": "nginx:latest",
                "Env": ["PATH=/usr/bin"]
            }
        }
        """
        let data = try #require(json.data(using: .utf8))
        let detail = try JSONDecoder().decode(DockerContainerDetail.self, from: data)

        #expect(detail.state.running == true)
        #expect(detail.config?.image == "nginx:latest")
    }
}

import SwiftUI

/// The signature screen: a capture bar up top, a loose scatter of not-yet-
/// filed sticky notes in the middle, and four labeled bins along the
/// bottom. Filing a note — automatically for Pro, by tap for Free — drives
/// a spring animation of that note's position and rotation straight to
/// zero at its bin, which is the entire visual payoff of the app.
struct CaptureView: View {
    @EnvironmentObject private var itemStore: ItemStore
    @EnvironmentObject private var storeManager: StoreManager
    @StateObject private var speechCapture = SpeechCapture()

    @State private var draftText = ""
    @State private var speechError: String?
    @State private var canvasSize: CGSize = .zero
    @State private var binFrames: [Bucket: CGRect] = [:]
    @State private var motions: [UUID: NoteMotion] = [:]
    @State private var pendingRemoval: Set<UUID> = []
    @State private var receivingBucket: Bucket?
    @State private var selectedNoteID: UUID?
    @State private var showBucketPicker = false
    @State private var selectedBucketForDetail: Bucket?

    private struct NoteMotion {
        var point: CGPoint
        var rotation: Double
    }

    private var displayedNotes: [Item] {
        itemStore.unfiledItems + itemStore.items.filter { pendingRemoval.contains($0.id) }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LooseEndsTheme.backgroundGradient.ignoresSafeArea()

                if displayedNotes.isEmpty {
                    Text("Empty desk.\nSay or type what's on your mind.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(LooseEndsTheme.mutedText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 220)
                }

                VStack(spacing: 0) {
                    captureBar
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    Spacer(minLength: 0)

                    binsRow
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                }

                ForEach(displayedNotes) { item in
                    StickyNoteView(item: item, width: 116)
                        .rotationEffect(.degrees(motions[item.id]?.rotation ?? fallbackRotation(for: item.id)))
                        .position(motions[item.id]?.point ?? fallbackPosition(for: item.id, in: geo.size))
                        .transition(.scale.combined(with: .opacity))
                        .onTapGesture { handleNoteTap(item) }
                        .zIndex(1)
                }
            }
            .onAppear {
                canvasSize = geo.size
                for item in itemStore.unfiledItems {
                    ensureMotion(for: item.id, canvasSize: geo.size)
                }
            }
            .onChange(of: geo.size) { _, newSize in
                canvasSize = newSize
            }
        }
        .coordinateSpace(name: "captureSpace")
        .onPreferenceChange(BinFramePreferenceKey.self) { frames in
            binFrames = frames
        }
        .onChange(of: speechCapture.liveTranscript) { _, newValue in
            if speechCapture.isRecording { draftText = newValue }
        }
        .confirmationDialog("File this thought", isPresented: $showBucketPicker, titleVisibility: .visible) {
            ForEach(Bucket.allCases) { bucket in
                Button(bucket.shortLabel) { fileManually(bucket: bucket) }
            }
            Button("Cancel", role: .cancel) { selectedNoteID = nil }
        }
        .sheet(item: $selectedBucketForDetail) { bucket in
            BucketDetailView(bucket: bucket).environmentObject(itemStore)
        }
    }

    // MARK: - Capture bar

    private var captureBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                TextField("What's on your mind...", text: $draftText, axis: .vertical)
                    .lineLimit(1...3)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(LooseEndsTheme.offWhite)
                    .tint(LooseEndsTheme.lime)

                Button(action: toggleRecording) {
                    Image(systemName: speechCapture.isRecording ? "waveform" : "mic.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(speechCapture.isRecording ? LooseEndsTheme.ink : LooseEndsTheme.lime)
                        .frame(width: 38, height: 38)
                        .background(
                            Circle().fill(speechCapture.isRecording ? LooseEndsTheme.lime : LooseEndsTheme.binFill)
                        )
                }
            }
            .padding(14)
            .looseEndsPanel(cornerRadius: 20)

            if !storeManager.isPro {
                Text("Free tier files manually — tap a thought below to choose its bucket. Pro sorts it for you.")
                    .font(.caption)
                    .foregroundStyle(LooseEndsTheme.mutedText)
            }

            if let speechError {
                Text(speechError)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Button(action: handleCapture) {
                Text("Capture")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(LooseEndsTheme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(LooseEndsTheme.lime, in: Capsule())
            }
            .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
        }
    }

    private var binsRow: some View {
        HStack(spacing: 10) {
            ForEach(Bucket.allCases) { bucket in
                BinView(
                    bucket: bucket,
                    count: itemStore.count(in: bucket),
                    isReceiving: receivingBucket == bucket
                ) {
                    selectedBucketForDetail = bucket
                }
            }
        }
    }

    // MARK: - Actions

    private func toggleRecording() {
        speechError = nil
        if speechCapture.isRecording {
            let transcript = speechCapture.stopRecording()
            if !transcript.isEmpty { draftText = transcript }
        } else {
            Task {
                let authorized = await speechCapture.requestAuthorization()
                guard authorized else {
                    speechError = "Microphone/speech access was declined. You can still type."
                    return
                }
                do {
                    try speechCapture.startRecording()
                } catch {
                    speechError = (error as? SpeechCapture.CaptureError)?.errorDescription ?? "Couldn't start listening."
                }
            }
        }
    }

    private func handleCapture() {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if speechCapture.isRecording { speechCapture.stopRecording() }

        let item = itemStore.capture(text)
        draftText = ""
        ensureMotion(for: item.id, canvasSize: canvasSize)

        if storeManager.isPro {
            autoTriage(item)
        }
    }

    private func autoTriage(_ item: Item) {
        Task {
            switch await AIProxyClient.shared.triage(rawText: item.rawText) {
            case .success(let result):
                fileNote(itemID: item.id, bucket: result.bucket, result: result, autoTriaged: true)
            case .failure:
                // Never lose it: fall back to Follow-up with no fields.
                fileNote(itemID: item.id, bucket: .followUp, result: nil, autoTriaged: false)
            }
        }
    }

    private func handleNoteTap(_ item: Item) {
        guard !storeManager.isPro else { return }
        guard !pendingRemoval.contains(item.id) else { return }
        selectedNoteID = item.id
        showBucketPicker = true
    }

    private func fileManually(bucket: Bucket) {
        guard let id = selectedNoteID else { return }
        fileNote(itemID: id, bucket: bucket, result: nil, autoTriaged: false)
        selectedNoteID = nil
    }

    /// The one animation the whole app hangs on: snap the note's position
    /// and rotation to its bin with a spring, commit the filing, then clean
    /// up a beat later once the motion has settled.
    private func fileNote(itemID: UUID, bucket: Bucket, result: TriageResult?, autoTriaged: Bool) {
        guard let binFrame = binFrames[bucket] else {
            itemStore.file(itemID: itemID, bucket: bucket, result: result, autoTriaged: autoTriaged)
            return
        }

        pendingRemoval.insert(itemID)
        let target = CGPoint(x: binFrame.midX, y: binFrame.midY)

        withAnimation(.spring(response: 0.55, dampingFraction: 0.68)) {
            motions[itemID] = NoteMotion(point: target, rotation: 0)
            receivingBucket = bucket
        }

        itemStore.file(itemID: itemID, bucket: bucket, result: result, autoTriaged: autoTriaged)

        Task {
            try? await Task.sleep(nanoseconds: 650_000_000)
            pendingRemoval.remove(itemID)
            motions.removeValue(forKey: itemID)
            if receivingBucket == bucket { receivingBucket = nil }
        }
    }

    // MARK: - Scatter placement

    private func ensureMotion(for id: UUID, canvasSize: CGSize) {
        guard motions[id] == nil else { return }
        motions[id] = NoteMotion(point: fallbackPosition(for: id, in: canvasSize), rotation: fallbackRotation(for: id))
    }

    /// Deterministic scatter position/rotation, seeded by the item's UUID,
    /// used both as the true initial placement and as a safe default before
    /// `ensureMotion` has run for a brand-new item.
    private func fallbackPosition(for id: UUID, in size: CGSize) -> CGPoint {
        guard size.width > 0, size.height > 0 else { return CGPoint(x: 100, y: 260) }
        var generator = SeededGenerator(seed: id.hashValue)
        let margin: CGFloat = 66
        let topInset: CGFloat = 168
        let bottomInset: CGFloat = 150
        let minX = margin
        let maxX = max(margin, size.width - margin)
        let minY = topInset
        let maxY = max(topInset, size.height - bottomInset)
        let x = CGFloat.random(in: minX...maxX, using: &generator)
        let y = CGFloat.random(in: minY...maxY, using: &generator)
        return CGPoint(x: x, y: y)
    }

    private func fallbackRotation(for id: UUID) -> Double {
        var generator = SeededGenerator(seed: id.hashValue ^ 0x5A5A)
        return Double.random(in: -18...18, using: &generator)
    }
}

#Preview {
    RootView()
        .environmentObject(ItemStore())
        .environmentObject(StoreManager())
}
